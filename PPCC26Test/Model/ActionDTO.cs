namespace PPCC2026.Model
{
    public class ActionDTO
    {
        public ActionType Type { get; set; }
        public string AttributeName { get; set; }
        public string TableName { get; set; }
        public string Value { get; set; }
    }

    public enum ActionType
    {
        OptionSet,
        TextField,
        CreateRecord,
        OpenRecord

    }
}
