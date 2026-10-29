using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Services.Description;

namespace PPCC26.DataAccess
{
    public class PluginRegistrationDataAccess : IPluginRegistrationDataAccess
    {
        const string RulesEnginePluginTypeName = "PPCC26.Plugins.EventManagerPlugin"; 
        const string SdkMessageProcessingStepSchemaName = "sdkmessageprocessingstep";

        protected IOrganizationService _orgService { get; set; }
        protected IOrganizationService ElevatedService { get; set; }
        protected ITracingService _tracingService { get; set; }

        public PluginRegistrationDataAccess(IOrganizationService orgService, ITracingService tracingservice)
        {
            _orgService = orgService;
            _tracingService = tracingservice;
        }

        public EntityReference RetrieveRulesEnginPluginReference()
        {
            QueryExpression query = new QueryExpression("plugintype")
            {
                ColumnSet = new ColumnSet("typename", "name")

            };

            query.Criteria.AddCondition("name", ConditionOperator.Equal, RulesEnginePluginTypeName);

            EntityCollection results = _orgService.RetrieveMultiple(query);

            var plugin = results.Entities.FirstOrDefault();
            return new EntityReference(plugin.LogicalName, plugin.Id);
        }

        public EntityReference RetrieveSdkMessageReference(string MessageName)
        {
            QueryExpression query = new QueryExpression("sdkmessage")
            {
                ColumnSet = new ColumnSet("name")

            };

            query.Criteria.AddCondition("name", ConditionOperator.Equal, MessageName);

            EntityCollection results = _orgService.RetrieveMultiple(query);

            var sdkMessage = results.Entities.FirstOrDefault();
            return new EntityReference(sdkMessage.LogicalName, sdkMessage.Id);
        }

        public EntityReference RetrieveSdkMessageFilterReference(string EntitySchemaName, EntityReference sdkMessage)
        {
            QueryExpression query = new QueryExpression("sdkmessagefilter")
            {
                ColumnSet = new ColumnSet(true)

            };

            query.Criteria.AddCondition("sdkmessageid", ConditionOperator.Equal, sdkMessage.Id);
            query.Criteria.AddCondition("primaryobjecttypecode", ConditionOperator.Equal, EntitySchemaName);

            EntityCollection results = _orgService.RetrieveMultiple(query);

            var sdkMessageFilter = results.Entities.FirstOrDefault();
            return new EntityReference(sdkMessageFilter.LogicalName, sdkMessageFilter.Id);
        }


        public Guid RegisterRulesEnginePlugin(string entitySchemaName, MessageNameEnum messageName, StageEnum stage, string triggerAttributes, int order)
        {
            string stepName = $"PPCC26.Plugins.RuleEnginePlugin: {stage.ToString()} {entitySchemaName} {messageName.ToString()}";

            Entity step = new Entity(SdkMessageProcessingStepSchemaName);

            // Name and Description
            step["name"] = stepName;
            step["description"] = $"Dynamically registered step: {stepName}";

            // Link to the Plugin Type (Class)
            step["plugintypeid"] = RetrieveRulesEnginPluginReference();

            // Link to the SDK Message and Filter (Table context)
            var sdkMessage = RetrieveSdkMessageReference(messageName.ToString());
            step["sdkmessageid"] = sdkMessage;
            step["sdkmessagefilterid"] = RetrieveSdkMessageFilterReference(entitySchemaName, sdkMessage);

            if (!string.IsNullOrWhiteSpace(triggerAttributes))
                step["filteringattributes"] = triggerAttributes;


            // Stage: Pre-Validation = 10, Pre-Operation = 20, Post-Operation = 40
            step["stage"] = new OptionSetValue((int)stage); // Post-Operation

            // Execution Mode: Synchronous = 0, Asynchronous = 1
            step["mode"] = new OptionSetValue(0); // Synchronous

            // Deployment: ServerOnly = 0, ClientOnly = 1, Both = 2
            step["supporteddeployment"] = new OptionSetValue(0);

            // Rank / Execution Order (Starts from 1)
            step["rank"] = order;

            // User Context: Calling User = null (or specify systemuserid GUID for impersonation)
            step["impersonatinguserid"] = null;

            // Create the step in Dataverse
            Guid stepId = _orgService.Create(step);

            return stepId;
        }

        public bool CheckAndDeletePluginStep(Guid pluginStep)
        {
            if (pluginStep.Equals(Guid.Empty))
                return false;

            QueryExpression query = new QueryExpression(SdkMessageProcessingStepSchemaName);
            query.Criteria.AddCondition("sdkmessageprocessingstepid", ConditionOperator.Equal, pluginStep);

            if (_orgService.RetrieveMultiple(query).Entities.Count == 0)
                return false;

            _orgService.Delete(SdkMessageProcessingStepSchemaName, pluginStep);
            return true;
        }

        public Guid RegisterPreImageForPluginStep(Guid pluginGuid, string preImageAttributes)
        {
            Entity preImage = new Entity("sdkmessageprocessingstepimage");
            preImage["name"] = "PreImage";
            preImage["messagepropertyname"] = "Target";
            preImage["attributes"] = preImageAttributes;
            preImage["entityalias"] = "PreImage";
            preImage["imagetype"] = new OptionSetValue(0); // Pre-Image
            preImage["sdkmessageprocessingstepid"] = new EntityReference(SdkMessageProcessingStepSchemaName, pluginGuid);
            Guid preImageId = _orgService.Create(preImage);
            return preImageId;
        }

    }
}