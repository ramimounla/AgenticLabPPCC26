using Microsoft.Xrm.Sdk;
using PPCC26.BusinessLogic;
using PPCC26.BusinessLogic.ActionProcessing;
using PPCC26.DataAccess;
using PPCC26.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Remoting.Contexts;
using System.Text;
using System.Threading.Tasks;
using System.Web.Services.Description;
using PPCC26.Services;

namespace PPCC26.Plugins
{
    //[CrmPluginRegistration("ppcc_RuleEnginePlugin")]

    [CrmPluginRegistration(
        message: MessageNameEnum.Create,
        entityLogicalName: "ppcc_customcase",
        stage: StageEnum.PostOperation,
        executionMode: ExecutionModeEnum.Synchronous,
        filteringAttributes: "ppcc_type",
        stepName: "PPCC26.Plugins.RuleEnginePlugin: Post-Create ppcc_customcase",
        executionOrder: 1,
        isolationModel: IsolationModeEnum.Sandbox,
        Description = "PPCC26.Plugins.RuleEnginePlugin: Post-Create ppcc_customcase"
     )]
    public class RuleEnginePlugin : IPlugin
    {
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


            // The InputParameters collection contains all the data passed in the message request.  
            if (context.InputParameters.Contains("Target") && context.InputParameters["Target"] is Entity)
            {
                // Obtain the target entity from the input parameters.  
                Entity entity = (Entity)context.InputParameters["Target"];


                // Retrieve the entity entity from the context, if available
                Entity preImage = null;
                if (context.PreEntityImages != null && context.PreEntityImages.Contains("PreImage"))
                {
                    preImage = context.PreEntityImages["PreImage"];
                }

                try
                {
                    var _targetEntity = entity;
                    var _preImageEntity = preImage;

                    var rulesEngineDataAccess = new EventManagerDataAccess(service, tracingService);
                    var actionFactory = new ActionFactory(service, tracingService);

                    tracingService.Trace($"PPCC26.Plugins.RuleEnginePlugin.Executing CORE Service");

                    var rulesEngineCore = new RulesEngineCore(rulesEngineDataAccess, actionFactory, _targetEntity, _preImageEntity, tracingService);

                    Enum.TryParse(context.MessageName, out MessageNameEnum messageNameEnum);

                    rulesEngineCore.Execute((StageEnum)context.Stage, messageNameEnum);
                }
                catch (InvalidPluginExecutionException ex)
                {
                    tracingService.Trace($"ERROR: ex.Message={ex.Message}");
                }
                catch (Exception ex)
                {
                    tracingService.Trace($"ERROR: ex.Message={ex.Message}");
                }

                tracingService.Trace($"PPCC26.Plugins.RuleEnginePlugin.Executed {DateTime.UtcNow}");
            }


           
        }
    }
}
