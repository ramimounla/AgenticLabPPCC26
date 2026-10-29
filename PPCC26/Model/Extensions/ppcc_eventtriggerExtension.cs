using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.Model
{
    public partial class PpCc_EventTrigger
    {
        public  IEnumerable<PpCc_RuleGroup> Groups { get; set; }
    }
}
