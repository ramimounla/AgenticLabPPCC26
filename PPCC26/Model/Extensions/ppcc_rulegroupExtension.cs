using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.Model
{
    partial class PpCc_RuleGroup
    {
        public IEnumerable<PpCc_RuleAction> Actions { get; set; }
        public IEnumerable<PpCc_RuleCondition> Conditions { get; set; }
    }
}
