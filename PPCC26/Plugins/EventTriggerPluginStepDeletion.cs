using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using PPCC26.DataAccess;
using PPCC26.BusinessLogic;
using PPCC26.Model;

namespace PPCC26.Plugins
{

    //[CrmPluginRegistration(
    //    message: MessageNameEnum.Delete,
    //    entityLogicalName: PpCc_EventTrigger.EntityLogicalName,
    //    stage: StageEnum.PreOperation,
    //    executionMode: ExecutionModeEnum.Synchronous,
    //    filteringAttributes: "",
    //    stepName: "PPCC26.Plugins.EventTriggerPluginStepDeletion: Pre-Delete ppcc_eventtrigger",
    //    executionOrder: 1,
    //    isolationModel: IsolationModeEnum.Sandbox,
    //    Description = "PPCC26.Plugins.EventTriggerPluginStepDeletion: Pre-Delete ppcc_eventtrigger",
    //     Image1Type = ImageTypeEnum.PreImage,
    //     Image1Name = "PreImage",
    //     Image1Attributes = "ppcc_plugintypeid"
    // )]
    public class EventTriggerPluginStepDeletion : IPlugin
    {
        IOrganizationService service;

        public void Execute(IServiceProvider serviceProvider)
        {
            //localcontext.Trace($"PPCC26.Plugins.EventTriggerPluginStepDeletion.Executing {DateTime.UtcNow}");

            //if (localcontext.PluginExecutionContext.MessageName != "Delete")
            //{
            //    throw new InvalidPluginExecutionException(
            //        $"This operation is not allowed yet. Expected 'Delete', but received '{localcontext.PluginExecutionContext.MessageName}'."
            //    );
            //}

            //try
            //{
            //    var target = localcontext.PluginExecutionContext.GetPreImage<ppcc_eventtrigger>();

            //    if (!target.Contains("ppcc_plugintypeid") || string.IsNullOrWhiteSpace(target.ppcc_PluginTypeId))
            //    {
            //        localcontext.Trace($"PPCC26.Plugins.EventTriggerPluginStepDeletion exiting because ppcc_PluginTypeId is not provided, plugin step not registered. Nothing to delete.");
            //        return;
            //    }

            //    if (!Guid.TryParse(target.ppcc_PluginTypeId, out Guid parsedGuid))
            //    {
            //        localcontext.Trace($"PPCC26.Plugins.EventTriggerPluginStepDeletion exiting because could not parse GUID {target.ppcc_PluginTypeId}");
            //        return;
            //    }

            //    var pluginRegistrationDataAccess = new PluginRegistrationDataAccess(localcontext.OrganizationService, localcontext.TracingService);

            //    pluginRegistrationDataAccess.CheckAndDeletePluginStep(parsedGuid);
            //    localcontext.Trace($"PPCC26.Plugins.EventTriggerPluginStepDeletion Deleted Plugin Step GUID {target.ppcc_PluginTypeId}");

            //}
            //catch (InvalidPluginExecutionException ex)
            //{
            //    localcontext.Trace($"ERROR: ex.Message={ex.Message}");
            //}
            //catch (Exception ex)
            //{
            //    localcontext.Trace($"ERROR: ex.Message={ex.Message}");
            //}

            //localcontext.Trace($"PPCC26.Plugins.EventTriggerPluginStepDeletion.Executed {DateTime.UtcNow}");
        }
    }
}
