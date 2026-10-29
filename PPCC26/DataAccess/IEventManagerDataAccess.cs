using Microsoft.Crm.Sdk.Messages;
using System;
using System.Collections.Generic;
using PPCC26.Model;

namespace PPCC26.DataAccess
{
    public interface IEventManagerDataAccess
    {
        IEnumerable<PpCc_EventTrigger> getEventTriggers(string tableName, PpCc_EventTrigger_PpCc_Stage stage, PpCc_EventTrigger_PpCc_Message message);
        string RetrieveEnvironmentVariable(string environmentVariable);
    }
}