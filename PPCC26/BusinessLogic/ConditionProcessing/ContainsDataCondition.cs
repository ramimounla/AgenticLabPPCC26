using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ConditionProcessing
{
    public class ContainsDataCondition : AbstractCondition
    {
        public ContainsDataCondition(Entity entity,Entity preImage, string attributeName, string value, ITracingService tracingService) : base(entity, preImage, attributeName, value, tracingService)
        {
        }

        public override bool Execute()
        {
            TracingService.Trace($"\tContains attribute {attributeName} {entity.Contains(attributeName)}");
            if(entity.Contains(attributeName))
            {
                TracingService.Trace($"\tAttribute null ? {entity[attributeName] == null}");
            }

            return entity.Contains(attributeName)
                && entity[attributeName] != null
                && !string.IsNullOrEmpty(entity[attributeName].ToString()); 
        }
    }
}
