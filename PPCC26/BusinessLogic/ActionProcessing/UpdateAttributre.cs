using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.IdentityModel.Metadata;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.BusinessLogic.ActionProcessing
{
    public  class UpdateAttributre : AbstractAction
    {
        public UpdateAttributre(Entity entity, Entity preIMage, string destinationAttributeName, string referenceAttributeName, string directiveJSON, string Value, IOrganizationService orgService, ITracingService tracingService) : base( entity,  preIMage,  destinationAttributeName,  referenceAttributeName,  directiveJSON,  Value,  orgService, tracingService)
        {

        }

        public override bool Execute()
        {
            if(string.IsNullOrWhiteSpace(Value))
                return false;

            var entityToUpdate = GetEntityToUpdate(DestinationAttributeName, Entity, PreImage);
            var attributeName = DestinationAttributeName.Split('.').Last();

            if (Value.Contains("{") && Value.Contains("}"))
                Value =  GetEnvironmentVariable(Value.Replace("{",string.Empty).Replace("}",string.Empty));

            if (int.TryParse(Value, out int intValue))
            {
                TracingService.Trace($"Parsing int Value: {Value}");
                entityToUpdate[attributeName] = new OptionSetValue(intValue);
            }
            else if (bool.TryParse(Value, out bool boolValue))
            {
                TracingService.Trace($"Parsing boolean Value: {Value}");
                entityToUpdate[attributeName] = boolValue;
            }
            else
            {
                TracingService.Trace($"Setting string Value: {Value}");
                entityToUpdate[attributeName] = Value;
            }


            TracingService.Trace("Updating entity");
            OrgService.Update(entityToUpdate);

            return true;
        }

        //One lookup hop
        private Entity GetEntityToUpdate(string destinationAttribute, Entity entity, Entity preimage)
        {
            if (!destinationAttribute.Contains("."))
                return entity;

            var lookupName = destinationAttribute.Split('.')[0];

            var entityReference = (EntityReference)preimage[lookupName];

            TracingService.Trace("Swapping to new entity to update {0}", entityReference.LogicalName);

            return new Entity(entityReference.LogicalName, entityReference.Id);
        }

    }
}
