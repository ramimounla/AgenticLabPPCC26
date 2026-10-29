using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ConditionProcessing
{
    public class ConditionFactory
    {
        
        private static readonly Dictionary<string, Type> conditionTypes;

        static ConditionFactory()
        {

            // Find all non-abstract subclasses of AbstractAction in the current assembly
            conditionTypes = new Dictionary<string, Type>()
            {
                { "Equals", typeof(EqualsDataCondition)},
                { "NotEquals", typeof(NotEqualsDataCondition)},
                { "DoesNotContainsData", typeof(DoesNotContainsDataCondition)},
                { "ContainsData", typeof(ContainsDataCondition)}
            };
        }

        // Example parameters: className, preImage, destinationAttribute, value, tracingService        
        public static AbstractCondition GenerateConditionClass(string operand, Entity entity, Entity preImage, string attributeName, string value, ITracingService tracingService)
        {
            if (!conditionTypes.TryGetValue(operand, out var type))
                throw new ArgumentException($"Condition type '{operand}' not found.");
            
            // Use reflection to instantiate the action
            return (AbstractCondition)Activator.CreateInstance(type, entity, preImage, attributeName, value, tracingService);
        }
    }
}
