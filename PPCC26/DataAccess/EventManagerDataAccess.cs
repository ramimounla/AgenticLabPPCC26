using Microsoft.Crm.Sdk.Messages;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Collections.Generic;
using System.Linq;
using PPCC26.Model;
using System.Net.Mime;
using System.Runtime.Remoting.Services;
using System.Text;
using System.Threading.Tasks;
using System.Web.Services.Description;
using System.Workflow.Runtime.Tracking;

namespace PPCC26.DataAccess
{
    public class EventManagerDataAccess : IEventManagerDataAccess
    {
        IOrganizationService _orgService;
        ITracingService _tracingService { get; set; }
        DataverseContext _context;

        public EventManagerDataAccess(IOrganizationService orgService, ITracingService tracingservice)
        {
            _orgService = orgService;
            _tracingService = tracingservice;
            _context = new DataverseContext(_orgService);
        }

        public IEnumerable<PpCc_EventTrigger> getEventTriggers(string tableName, PpCc_EventTrigger_PpCc_Stage stage, PpCc_EventTrigger_PpCc_Message message)
        {

            _tracingService.Trace($"Values: Talbe {tableName} Stage {(int)stage} Message {(int)message}");

            var eventTriggers = (from e in _context.PpCc_EventTriggerSet
                                 where e.PpCc_Table == tableName
                                 && e.PpCc_Stage == stage
                                 && e.PpCc_Message == message
                                 && e.StateCode == PpCc_EventTrigger_StateCode.Active
                                 orderby e.PpCc_Order ascending
                                 select e).ToList();

            foreach (var eventTrigger in eventTriggers)
            {
                //Exit criteria if not found
                if (eventTrigger == null)
                    return null;

                eventTrigger.Groups = (from g in _context.PpCc_RuleGroupSet
                                       where g.PpCc_EventTriggerId.Id == eventTrigger.Id
                                       && g.StateCode == PpCc_RuleGroup_StateCode.Active
                                       orderby g.PpCc_Order ascending
                                       select g).ToList();

                foreach (var ruleGroup in eventTrigger.Groups)
                {
                    ruleGroup.Conditions = (from c in _context.PpCc_RuleConditionSet
                                            where c.PpCc_RuleGroupId.Id == ruleGroup.Id
                                            && c.StateCode == PpCc_RuleCondition_StateCode.Active
                                            orderby c.PpCc_Order ascending
                                            select c).ToList();

                    ruleGroup.Actions = (from a in _context.PpCc_RuleActionSet
                                         where a.PpCc_RuleGroupId.Id == ruleGroup.Id
                                         && a.StateCode == PpCc_RuleAction_StateCode.Active
                                         orderby a.PpCc_Order ascending
                                         select a).ToList();
                }
            }

            return eventTriggers;
        }

        public string RetrieveEnvironmentVariable(string environmentVariable)
        {
            _tracingService.Trace($"RetrieveEnvironmentVariable: resolving '{environmentVariable}'");

            var query = new QueryExpression("environmentvariabledefinition")
            {
                ColumnSet = new ColumnSet("defaultvalue"),
                TopCount = 1,
                Criteria =
                {
                    Conditions =
                    {
                        new ConditionExpression("schemaname", ConditionOperator.Equal, environmentVariable)
                    }
                },
                LinkEntities =
                {
                    new LinkEntity("environmentvariabledefinition", "environmentvariablevalue",
                                   "environmentvariabledefinitionid", "environmentvariabledefinitionid",
                                   JoinOperator.LeftOuter)
                    {
                        EntityAlias = "v",
                        Columns = new ColumnSet("value")
                    }
                },
                Orders =
                {
                    new OrderExpression("modifiedon", OrderType.Descending)
                }
            };

            var results = _orgService.RetrieveMultiple(query);

            if (results.Entities.Count == 0)
            {
                _tracingService.Trace($"RetrieveEnvironmentVariable: '{environmentVariable}' is not defined");
                throw new InvalidPluginExecutionException("Environment variable not found: " + environmentVariable);
            }

            var definition = results.Entities[0];

            // The environment-specific value always takes precedence over the solution default
            var currentValue = definition.GetAttributeValue<AliasedValue>("v.value");
            if (currentValue != null && !string.IsNullOrEmpty(currentValue.Value as string))
            {
                _tracingService.Trace($"RetrieveEnvironmentVariable: '{environmentVariable}' resolved from current value");
                return (string)currentValue.Value;
            }

            _tracingService.Trace($"RetrieveEnvironmentVariable: '{environmentVariable}' falling back to default value");
            return definition.GetAttributeValue<string>("defaultvalue");
        }
    }
}
