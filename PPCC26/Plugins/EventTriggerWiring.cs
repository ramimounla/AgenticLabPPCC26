using Microsoft.Xrm.Sdk;
using PPCC26.BusinessLogic;
using PPCC26.DataAccess;
using PPCC26.Model;
using System;
using System.Collections.Generic;
using System.IdentityModel.Protocols.WSTrust;
using System.Linq;
using System.Net.Http.Headers;
using System.Runtime.Remoting.Contexts;
using System.Text;
using System.Threading.Tasks;
using System.Web.Services.Description;
using System.Web.UI.WebControls;

namespace PPCC26.Plugins
{

    //[CrmPluginRegistration(
    //    message: MessageNameEnum.Create,
    //    entityLogicalName: PpCc_EventTrigger.EntityLogicalName,
    //    stage: StageEnum.PreOperation,
    //    executionMode: ExecutionModeEnum.Synchronous,
    //    filteringAttributes: "ppcc_attributes, ppcc_message, ppcc_stage, ppcc_table, ppcc_order,ppcc_preimageattributes",
    //    stepName: "PPCC26.Plugins.EventTriggerWiring: Pre-Create ppcc_eventtrigger",
    //    executionOrder: 1,
    //    isolationModel: IsolationModeEnum.Sandbox,
    //    Description = "PPCC26.Plugins.EventTriggerWiring: Pre-Create ppcc_eventtrigger"
    // ),
    //    CrmPluginRegistration(
    //    message: MessageNameEnum.Update,
    //    entityLogicalName: PpCc_EventTrigger.EntityLogicalName,
    //    stage: StageEnum.PreOperation,
    //    executionMode: ExecutionModeEnum.Synchronous,
    //    filteringAttributes: "statuscode",
    //    stepName: "PPCC26.Plugins.EventTriggerWiring: Pre-Update ppcc_eventtrigger",
    //    executionOrder: 1,
    //    isolationModel: IsolationModeEnum.Sandbox,
    //    Description = "PPCC26.Plugins.EventTriggerWiring: Pre-Update ppcc_eventtrigger",
    //    Image1Type = ImageTypeEnum.PreImage,
    //    Image1Name = "PreImage",
    //    Image1Attributes = "ppcc_attributes, ppcc_message, ppcc_stage, ppcc_table, ppcc_order,ppcc_plugintypeid,ppcc_preimageattributes"
    // )]
    public class EventTriggerWiring : IPlugin
    {
        PpCc_EventTrigger _targetEntity;
        PpCc_EventTrigger _preImageEntity;
        List<string> listOfAttributes = new List<string>();
        MessageNameEnum currentPluginMessageNameEnum;
        MessageNameEnum messageNameForPluginToRegister;
        int order;
        Guid pluginGuid;

        IOrganizationService service;

        public void Execute(IServiceProvider serviceProvider)
        {

            // Obtain the tracing service
            ITracingService tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            
            // Obtain the execution context from the service provider.  
            IPluginExecutionContext context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

            // Obtain the organization service
            IOrganizationServiceFactory serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            service = serviceFactory.CreateOrganizationService(context.UserId);


            //// The InputParameters collection contains all the data passed in the message request.  
            //if (context.InputParameters.Contains("Target") && context.InputParameters["Target"] is Entity)
            //{
            //    // Obtain the target entity from the input parameters.  
            //    Entity entity = (Entity)context.InputParameters["Target"];


            //    // Retrieve the entity entity from the context, if available
            //    Entity preImage = null;
            //    if (context.PreEntityImages != null && context.PreEntityImages.Contains("PreImage"))
            //    {
            //        preImage = context.PreEntityImages["PreImage"];
            //    }


            //}

            //tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring.Executing {DateTime.UtcNow}");
            //listOfAttributes.AddRange(new string[] { "ppcc_attributes", "ppcc_message", "ppcc_stage", "ppcc_table", "ppcc_order", "ppcc_plugintypeid", "ppcc_preimageattributes" });



            //if (!context.InputParameters.Contains("Target") || !(context.InputParameters["Target"] is Entity))
            //    return;
            
            //    // Obtain the target entity from the input parameters.  
            //    var tareget = ((Entity)context.InputParameters["Target"])ToEntity<PpCc_EventTrigger>();


            //// Retrieve the entity entity from the context, if available
            //Entity preImage = null;
            //    if (context.PreEntityImages != null && context.PreEntityImages.Contains("PreImage"))
            //    {
            //        preImage = context.PreEntityImages["PreImage"];
            //    }


            //    PpCc preImage = context.PreEntityImages["test"].ToEntity<PpCc>();

            //    _targetEntity = context.PreIM <PpCc_EventTrigger>();
            //_preImageEntity = context.PreEntityImages["Target"].ToEntity<PpCc_EventTrigger>();
            //Enum.TryParse(tracingService.PluginExecutionContext.MessageName, out currentPluginMessageNameEnum);

            //var pluginRegistrationDataAccess = new PluginRegistrationDataAccess(service, tracingService);

            //var eventTriggerWiringService = new EventTriggerWiringService(pluginRegistrationDataAccess, tracingService);

            //if (currentPluginMessageNameEnum == MessageNameEnum.Create)
            //{
            //    populateVariables();
            //    tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring: Creating new registration for {messageNameForPluginToRegister} on {_targetEntity.PpCc_Table} at stage {_targetEntity.PpCc_Stage} with order {order}");
            //    pluginGuid = eventTriggerWiringService.UpsertPluginRegistration(_targetEntity.PpCc_Table, messageNameForPluginToRegister, (StageEnum)(int)_targetEntity.PpCc_Stage, order, Guid.Empty, _targetEntity.PpCc_Attributes, _targetEntity.PpCc_PreImageAttributes);
            //    tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring registered pluing {pluginGuid.ToString()}");
            //    _targetEntity.ppcc_PluginTypeId = pluginGuid.ToString();
            //}
            //else if (currentPluginMessageNameEnum == MessageNameEnum.Update)
            //{
            //    if (_targetEntity.StatusCode == PpCc_EventTrigger_StatusCode.Reregister)
            //    {
            //        populateIncomingEntity();
            //        populateVariables();
            //        tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring: Updating existing registration for {messageNameForPluginToRegister} on {_targetEntity.PpCc_Table} at stage {_targetEntity.PpCc_Stage} with order {order}");
            //        tracingService.Trace($"Is preimage null? {_preImageEntity == null}");
            //        if (_preImageEntity != null)
            //        {
            //            string preImageValue = _preImageEntity.Contains("ppcc_preimageattributes") ? _preImageEntity["ppcc_preimageattributes"].ToString() : "Nothing";
            //            tracingService.Trace($"Is preimage attributes = {preImageValue}");
            //        }

            //        var registeredPlugin = string.IsNullOrEmpty(_targetEntity.ppcc_PluginTypeId) ? Guid.Empty : Guid.Parse(_targetEntity.ppcc_PluginTypeId);
            //        pluginGuid = eventTriggerWiringService.UpsertPluginRegistration(_targetEntity.ppcc_table, messageNameForPluginToRegister, (StageEnum)(int)_targetEntity.ppcc_stage, order, registeredPlugin, _targetEntity.ppcc_attributes, _targetEntity.ppcc_PreImageAttributes);
            //        tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring registered pluing {pluginGuid.ToString()}");
            //        _targetEntity.statuscode = ppcc_eventtrigger_statuscode.Active;
            //        _targetEntity.ppcc_PluginTypeId = pluginGuid.ToString();
            //    }
            //    else
            //    {
            //        tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring: No action required record status is {_targetEntity.statuscode} registering for {messageNameForPluginToRegister} on {_targetEntity.ppcc_table} at stage {_targetEntity.ppcc_stage} with order {order}");
            //    }

            //}
            //else
            //{
            //    throw new InvalidPluginExecutionException(
            //        $"This operation is not allowed yet. Expected 'Create' or 'Update', but received '{tracingService.PluginExecutionContext.MessageName}'."
            //    );
            //}

            tracingService.Trace($"PPCC26.Plugins.EventTriggerWiring.Executed {DateTime.UtcNow}");
        }

        private void populateVariables()
        {
            Enum.TryParse(_targetEntity.PpCc_Message.ToString(), out messageNameForPluginToRegister);
            order = _targetEntity.PpCc_Order ?? 1;
        }

        private void populateIncomingEntity()
        {
            foreach (var attribute in listOfAttributes.Where(a => !_targetEntity.Contains(a) && _preImageEntity.Contains(a) && _preImageEntity.Attributes[a] != null))
                _targetEntity[attribute] = _preImageEntity[attribute];
        }
    }
}
