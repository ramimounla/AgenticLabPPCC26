using PPCC26.DataAccess;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PPCC26.Model
{
    public class EventManagerService
    {
        private IEventManagerDataAccess _eventManagerDataAccess;

        public EventManagerService(IEventManagerDataAccess eventManagerDataAccess)
        {
            _eventManagerDataAccess = eventManagerDataAccess;
        }

        public bool Execute()
        {
            return true;

        }

    }
}
