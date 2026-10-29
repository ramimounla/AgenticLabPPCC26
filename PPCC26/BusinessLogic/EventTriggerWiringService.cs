using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.Services.Description;
using PPCC26.DataAccess;

namespace PPCC26.BusinessLogic
{
    public class EventTriggerWiringService
    {
        protected IOrganizationService OrgService { get; set; }
        protected ITracingService TracingService { get; set; }

        IPluginRegistrationDataAccess _pluginRegistrationDal;

        public EventTriggerWiringService(IPluginRegistrationDataAccess pluginRegistrationDal, ITracingService tracingservice)
        {
            _pluginRegistrationDal = pluginRegistrationDal;
            TracingService = tracingservice;
        }

        public Guid UpsertPluginRegistration(string entitySchemaName, MessageNameEnum message, StageEnum stage, int order, Guid existingPluginGuid, string triggerAttributes, string preImageAttributes)
        {
            TracingService.Trace($"EventTriggerWiringService.UpsertPluginRegistration: entitySchemaName={entitySchemaName}, message={message}, stage={stage}, order={order}, existingPlugin={existingPluginGuid}, preImageAttributes={preImageAttributes}");
            
            _pluginRegistrationDal.CheckAndDeletePluginStep(existingPluginGuid);
            TracingService.Trace($"EventTriggerWiringService.UpsertPluginRegistration: Deleted existing plugin step with GUID {existingPluginGuid}");

            var pluginGuid = _pluginRegistrationDal.RegisterRulesEnginePlugin(entitySchemaName, message, stage, triggerAttributes, order);
            TracingService.Trace($"EventTriggerWiringService.UpsertPluginRegistration: Registered plugin step with GUID {pluginGuid}");

            TracingService.Trace($"EventTriggerWiringService.UpsertPluginRegistration: preimage variables {preImageAttributes ?? "Empty"}");
            if (!string.IsNullOrWhiteSpace(preImageAttributes))
            {
                _pluginRegistrationDal.RegisterPreImageForPluginStep(pluginGuid, preImageAttributes);
                TracingService.Trace($"EventTriggerWiringService.UpsertPluginRegistration: Registered pre-image for plugin step with GUID {pluginGuid}");
            }
            return pluginGuid;
        }
    }
}
