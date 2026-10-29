using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ConditionProcessing
{
    public class EqualsDataCondition : AbstractCondition
    {
        public EqualsDataCondition(Entity entity,Entity preImage, string attributeName, string value, ITracingService tracingService) : base(entity, preImage, attributeName, value, tracingService)
        {
        }

        public override bool Execute()
        {

                TracingService.Trace($"\tEntity null? {entity == null}.");
            // Implementation of the condition logic goes here
            // For example, check if the entity equals specific data
            // This is just a placeholder for actual logic
            if (!entity.Attributes.Contains(attributeName))
            {
                TracingService.Trace($"\tAttribute {attributeName} not in entity.");
                return false;
            }

            var attribute = entity[attributeName];

            if (attribute == null)
                return false;

            //DO add more types here
            if (attribute.GetType().Equals(typeof(OptionSetValue)))
                return compare((OptionSetValue)attribute, value);
            else if (attribute.GetType().Equals(typeof(bool)))
                return attribute.Equals(bool.Parse(value));
            else if (attribute.GetType().Equals(typeof(int)))
                return attribute.Equals(int.Parse(value));
            else if (attribute.GetType().Equals(typeof(EntityReference)))
                return compare((EntityReference)attribute, new Guid(value));

            throw new NotImplementedException("Condition for type " + attribute.GetType().Name + " not implemented yet.");
        }

        private bool compare(OptionSetValue optionSet, string value)
        {
            return optionSet.Value.Equals(int.Parse(value));
        }

        private bool compare(bool booleanSource, string value)
        {
            return booleanSource.Equals(bool.Parse(value));
        }

        private bool compare(int intSource, string value)
        {
            return intSource == int.Parse(value);
        }

        private bool compare(EntityReference entityReference, Guid value)
        {
            TracingService.Trace($"\t Staring entity reference equals comparison");
            TracingService.Trace($"\t Expected value {value.ToString()} actual {entityReference.Id.ToString()}");
            var comparisonResult = entityReference.Id.Equals(value);
            TracingService.Trace($"\t Result: {comparisonResult}");
            return comparisonResult;
        }
    }
}
