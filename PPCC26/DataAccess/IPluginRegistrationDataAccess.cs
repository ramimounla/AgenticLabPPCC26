using Microsoft.Xrm.Sdk;
using System;

namespace PPCC26.DataAccess
{
    public interface IPluginRegistrationDataAccess
    {
        EntityReference RetrieveRulesEnginPluginReference();
        EntityReference RetrieveSdkMessageReference(string MessageName);
        EntityReference RetrieveSdkMessageFilterReference(string EntitySchemaName, EntityReference sdkMessage);
        bool CheckAndDeletePluginStep(Guid pluginStep);

        Guid RegisterRulesEnginePlugin(string entitySchemaName, MessageNameEnum messageName, StageEnum stage, string triggerAttributes, int order);

        Guid RegisterPreImageForPluginStep(Guid pluginGuid, string preImageAttributes);
    }
}