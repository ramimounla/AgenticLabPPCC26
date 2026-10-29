using Microsoft.Xrm.Sdk;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Web.UI.WebControls;
using System.Windows;
using PPCC26.DataAccess;
using PPCC26.Model;
using PPCC26.BusinessLogic.ConditionProcessing;
using PPCC26.BusinessLogic.ActionProcessing;

namespace PPCC26.Services
{
    public class RulesEngineCore
    {
        private ITracingService _tracingService { get; set; }
        private IEventManagerDataAccess _ruleEngineDataAccess { get; set; }

        private Entity _entity;
        private Entity _mergedEntity;
        private Entity _preImage;
        private ActionFactory _actionFactory;

        public RulesEngineCore(IEventManagerDataAccess ruleEngineDataAccess, ActionFactory actionFactory, Entity entity, Entity preImage,  ITracingService tracingservice)
        {
            _tracingService = tracingservice;
            _ruleEngineDataAccess = ruleEngineDataAccess;
            _actionFactory = actionFactory;
            _entity = entity;
            _preImage = preImage;

            //_mergedEntity = new Entity(_entity.LogicalName);
            //_mergedEntity.Id = _entity.Id;
            //_mergedEntity.Attributes.AddRange(_entity.Attributes);
        }

        public void Execute(int stageEnum, int messageEnum)
        {
            Execute((StageEnum)stageEnum, (MessageNameEnum)messageEnum);
        }

        public void Execute(StageEnum stageEnum, MessageNameEnum messageEnum)
        {
            //Convert between optionsets and enums
            PpCc_EventTrigger_PpCc_Stage stage = (PpCc_EventTrigger_PpCc_Stage)(int)stageEnum;
            Enum.TryParse(messageEnum.ToString(), out PpCc_EventTrigger_PpCc_Message message);
            var tableName = _entity.LogicalName;

            var ruleTriggers = _ruleEngineDataAccess.getEventTriggers(tableName, stage, message);

            if (ruleTriggers.Count() == 0)
            {
                _tracingService.Trace($"No trigger founder for table {tableName} message {message} stage {stage}");
                return;
            }

            foreach (var ruleTrigger in ruleTriggers)
            {
                //if (!string.IsNullOrWhiteSpace(ruleTrigger.PpCc_PreImageAttributes))
                //    populateIncomingEntity(ruleTrigger.PpCc_PreImageAttributes.Split(',').ToList());
                
                var executeAllRules = ruleTrigger.PpCc_ExecuteAllRules == null ? false : (bool)ruleTrigger.PpCc_ExecuteAllRules;

                foreach (var ruleGroup in ruleTrigger.Groups)
                {
                    _tracingService.Trace($"\n\t>> Rule Group  #{ruleGroup.PpCc_Order} {ruleGroup.PpCc_Name}");
                    if (!AllConditionsPassed(ruleGroup.Conditions))
                    {
                        _tracingService.Trace($"\t<< Rule Group ** #{ruleGroup.PpCc_Order} {ruleGroup.PpCc_Name} [[FAILED]]");
                        continue;
                    }

                    _tracingService.Trace($"\t<< Rule Group ** #{ruleGroup.PpCc_Order} {ruleGroup.PpCc_Name} ||PASSED||");

                    ExecuteAllActions(ruleGroup.Actions);

                    if (!executeAllRules)
                        break;
                }
            }
        }

        private bool AllConditionsPassed(IEnumerable<PpCc_RuleCondition> Conditions)
        {
            foreach (var condition in Conditions)
            {
                var updatedValue = convertValueFromEnvironmentVariable(condition.PpCc_Value);
                _tracingService.Trace($"\tLooking up condition {condition.PpCc_Operand?.ToString()}");
                var conditionClass = ConditionFactory.GenerateConditionClass(condition.PpCc_Operand?.ToString(), _entity, _preImage, condition.PpCc_FieldName, updatedValue, _tracingService);

                _tracingService.Trace($"\tExecuting condition {conditionClass.GetType().FullName}");
                if (!conditionClass.Execute())
                {
                    _tracingService.Trace($"\t\tCondition {conditionClass.GetType().FullName} failed for {condition.PpCc_FieldName}");
                    return false;
                }
            }

            return true;
        }

        private void ExecuteAllActions(IEnumerable<PpCc_RuleAction> Actions)
        {
            foreach (var action in Actions)
            {
                var actionClass = _actionFactory.GenerateActionClass(action.PpCc_ActionType.ToString(), _entity, _preImage, action.PpCc_DestinationAttribute, action.PpCc_ReferenceAttribute, action.PpCc_DirectivesJSon, action.PpCc_Value);
                _tracingService.Trace($"\t\t* Executing action {actionClass.GetType().FullName}");
                actionClass.Execute();
            }
        }

        private string convertValueFromEnvironmentVariable(string value)
        {
            if (string.IsNullOrWhiteSpace(value) || !value.StartsWith("{") && !value.EndsWith("}"))
                return value;

            var environmentVariable = value.Substring(1, value.Length - 2);
            return _ruleEngineDataAccess.RetrieveEnvironmentVariable(environmentVariable);
        }

        //private void populateIncomingEntity(List<string> listOfAttributes)
        //{
        //    if (_preImage != null)
        //    {
        //        _tracingService.Trace($"pre image population");
        //        foreach (var attribute in listOfAttributes)
        //        {
        //            _tracingService.Trace($"entity contains {attribute} {_entity.Contains(attribute)}");
        //            _tracingService.Trace($"preimage contains {attribute} {_preImage.Contains(attribute)}");
        //            if (_preImage.Contains(attribute))
        //            {
        //                _tracingService.Trace($"preimage {attribute} value is null? {_preImage.Attributes[attribute] == null}");
        //            }



        //            if (!_entity.Contains(attribute) && _preImage.Contains(attribute) && _preImage.Attributes[attribute] != null)
        //            {
        //                _tracingService.Trace($"Adding {attribute} to merged entity");
        //                _mergedEntity[attribute] = _preImage[attribute];
        //            }
        //        }
        //    }
        //}
    }
}
