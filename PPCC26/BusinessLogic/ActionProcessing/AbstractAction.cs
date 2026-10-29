using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using PPCC26.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Workflow.Runtime.Tracking;

namespace PPCC26.BusinessLogic.ActionProcessing
{
    public abstract class AbstractAction
    {
        public string DestinationAttributeName;
        public string ReferenceAttributeName;
        public string DirectiveJSON;
        public string Value;
        protected Entity Entity;
        protected Entity PreImage;
        public IOrganizationService OrgService;
        public ITracingService TracingService;

        public AbstractAction(Entity entity, Entity preIMage, string destinationAttributeName, string referenceAttributeName, string directiveJSON, string value, IOrganizationService orgService, ITracingService tracingService)
        {
            Entity = entity;         // Assign entity
            PreImage = preIMage;
            DestinationAttributeName = destinationAttributeName;
            ReferenceAttributeName = destinationAttributeName;
            Value = value;
            DirectiveJSON = directiveJSON;
            OrgService = orgService;
            TracingService = tracingService;
        }

        public abstract bool Execute();

        protected string GetEnvironmentVariable(string schemaName)
        {
            if (string.IsNullOrWhiteSpace(schemaName))
                throw new ArgumentNullException(nameof(schemaName));

            // Query using FetchXml to join the definition and value tables efficiently
            string fetchXml = $@"
                <fetch top='1'>
                    <attribute name='value' />
                      <attribute name='defaultvalue' />
                      <filter type='and'>
                        <condition attribute='schemaname' operator='eq' value='{schemaName}' />
                      </filter>
                </fetch>";

            EntityCollection results = OrgService.RetrieveMultiple(new FetchExpression(fetchXml));

            // 0. Fallback: If no value record exists at all, query the definition table directly for the default value
            if (results.Entities.Count == 0)
                return GetDefaultVariableValueOnly(schemaName);

            Entity entity = results.Entities[0];

            // 1. Check for a specific environment variable value first
            if (entity.Contains("value"))
            {
                return entity.GetAttributeValue<string>("value");
            }

            // 2. Fall back to the default value from the definition if no specific value exists
            if (entity.Contains("def.defaultvalue"))
            {
                AliasedValue aliasedDefault = entity.GetAttributeValue<AliasedValue>("def.defaultvalue");
                return aliasedDefault?.Value?.ToString();
            }

            return null;
        }

        private string GetDefaultVariableValueOnly(string schemaName)
        {
            QueryExpression query = new QueryExpression("environmentvariabledefinition")
            {
                ColumnSet = new ColumnSet("defaultvalue"),
                Criteria = new FilterExpression
                {
                    Conditions = {
                        new ConditionExpression("schemaname", ConditionOperator.Equal, schemaName)
                    }
                }
            };

            EntityCollection results = OrgService.RetrieveMultiple(query);
            if (results.Entities.Count == 0)
                return null;

            return results.Entities[0].GetAttributeValue<string>("defaultvalue");
        }
    }
}
