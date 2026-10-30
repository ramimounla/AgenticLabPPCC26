using NUnit.Framework;
using System.Collections.Generic;
using Task = System.Threading.Tasks.Task;
using System.IO;
using System.Text.Json;
using PPCC2026.Model;

namespace PPCC2026.Tests.PPCC
{
    [TestFixture]
    public class PPCCUITest : BaseTest
    {
        string filePath = ".\\TestFixture\\UITest.json";

        [TestCase]
        public async Task CreateCustomCase()
        {
            // Get the test
            List<ActionDTO> actionList = JsonSerializer.Deserialize<List<ActionDTO>>(File.ReadAllText(filePath)) ?? [];

            await GetReady(url, appId, appName, username, password);

            foreach (var action in actionList)
            {
                await ExecuteAction(action);
            }

            await Navigation.Chill(10000);
        }
    }
}
