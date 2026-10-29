using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ConditionProcessing
{
    public class DoesNotContainsDataCondition : AbstractCondition
    {
        public DoesNotContainsDataCondition(Entity entity,Entity preImage, string attributeName, string value, ITracingService tracingService) : base(entity, preImage, attributeName, value, tracingService)
        {
        }

        public override bool Execute()
        {
            return !entity.Contains(attributeName) || entity[attributeName] == null || string.IsNullOrEmpty(entity[attributeName].ToString());
        }
    }
}
