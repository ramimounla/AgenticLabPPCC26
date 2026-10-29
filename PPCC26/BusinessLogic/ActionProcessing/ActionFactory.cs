using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ActionProcessing
{
    public class ActionFactory
    {
        
        private readonly Dictionary<string, Type> actionTypes;
        IOrganizationService _orgService;
        ITracingService _tracingservice;

        public ActionFactory(IOrganizationService orgService, ITracingService tracingservice)
        {
            _orgService = orgService;   
            _tracingservice = tracingservice;   

            // Find all non-abstract subclasses of AbstractAction in the current assembly
            actionTypes = new Dictionary<string, Type>()
            {
                { "UpdateAttribute", typeof(UpdateAttributre)},
                //{ "CalculateBusinessDays", typeof(CreateBusinessDaysSlaRecord)},
                //{ "CalculateandEndBusinessHours", typeof(CreateAndEndBusinessHoursSlaRecord)},
                //{ "FindandEndSLA", typeof(FindAndEndSla)}
            };
        }

        // Example parameters: className, preImage, destinationAttribute, value, tracingService        
        public AbstractAction GenerateActionClass(string actionName, Entity entity, Entity preImage, string destinationAttributeName, string referenceAttributeName, string directiveJSON, string value)
        {
            if (!actionTypes.TryGetValue(actionName, out var type))
                throw new ArgumentException($"Action type '{actionName}' not found.");

            // Use reflection to instantiate the action
            return (AbstractAction)Activator.CreateInstance(type, entity, preImage, destinationAttributeName, referenceAttributeName, directiveJSON, value, _orgService, _tracingservice);
        }
    }
}
