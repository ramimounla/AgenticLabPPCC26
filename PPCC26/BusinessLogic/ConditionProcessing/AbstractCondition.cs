using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ConditionProcessing
{
    public abstract class AbstractCondition
    {
        protected Entity entity { get; set; } // Added entity entity
        protected Entity preImage { get; set; } // Added entity entity
        public string attributeName { get; }
        public string value { get; }

        protected ITracingService TracingService;

        public AbstractCondition(Entity entity, Entity preImage, string attributeName, string value, ITracingService tracingService)
        {
            this.entity = entity;         // Assign entity
            this.preImage = preImage;
            this.attributeName = attributeName;
            this.value = value;
            TracingService = tracingService;
        }

        public abstract bool Execute();
    }
}
