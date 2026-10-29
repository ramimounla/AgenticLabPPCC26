//using PPCC26.Model
//using PPCC26.BusinessLogic
using PPCC26.DataAccess;
using Microsoft.Xrm.Sdk;
using System;
using System.Linq;

namespace PPCC26.Plugins
{
    public  class EventManager : IPlugin
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

                //var journeyDataLayer = new JourneyDataLayer(service, tracingService);

                //try
                //{
                //    var engineLogic = new EngineLogic(entity, preImage, context.MessageName, context.Stage, journeyDataLayer, service, tracingService);
                //    engineLogic.Execute();
                //}
                //catch (Exception ex)
                //{
                //    tracingService.Trace("CorePlugin error: {0}", ex.ToString());
                //    throw new InvalidPluginExecutionException("An error occurred in CorePlugin: " + ex.Message, ex);
                //}
            }
        }
    }
}
