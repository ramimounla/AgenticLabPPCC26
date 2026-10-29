using Bogus.DataSets;
using Microsoft.Playwright;
using Microsoft.Xrm.Sdk;
using NUnit.Framework;
using PPCC2026.Common;
using PPCC2026.Common.Helper;
using PPCC2026.Common.Playwright;
using PPCC2026.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Policy;
using System.Text;
using System.Threading.Tasks;

namespace PPCC2026.Tests
{
    public abstract class BaseTest
    {
        protected UciNavigation Navigation;

        protected string url;
        protected string appId;
        protected string appName;
        protected string username;
        protected string password;
        
        [SetUp]
        public void LoadConfiguration()
        {
            username = TestConfig.Username;
            password = TestConfig.Password;
            url = TestConfig.OnlineCrmUrl;
            appId= TestConfig.AppId;
            appName= TestConfig.AppName;
        }

        public async Task GetReady(string url, string appId, string name, string username, string password)
        {
            var PlaywrightInstance = await Playwright.CreateAsync();

            IBrowserType browserType = PlaywrightInstance.Chromium;
            //PlaywrightInstance.Firefox;
            //PlaywrightInstance.Webkit;
            //PlaywrightInstance.Chromium;

            BrowserTypeLaunchOptions launchOptions = PlaywrightBrowserOptions.GetLaunchOptions();
            var Browser = await browserType.LaunchAsync(launchOptions);

            BrowserNewContextOptions contextOptions = new()
            {
                ViewportSize = ViewportSize.NoViewport,
                IgnoreHTTPSErrors = true
            };

            var Context = await Browser.NewContextAsync(contextOptions);
            var Page = await Context.NewPageAsync();

            Navigation = new UciNavigation(Page, url, appId, name);

            await DynamicsLoginHelper.LoginAsync(Page, new UserDTO(username, password, string.Empty));
            await DynamicsLoginHelper.WaitForDynamicsReadyAsync(Page);
        }

        public async Task ExecuteAction(ActionDTO action)
        {
            switch (action.Type)
            {
                case ActionType.CreateRecord:
                    await Navigation.OpenRecordAsync(action.TableName);
                    await Navigation.WaitForPageLoad();
                    break;

                case ActionType.TextField:
                    await Navigation.SetTextAsync(action.AttributeName, action.Value);
                    break;

                case ActionType.OptionSet:
                    await Navigation.SelectOptionAsync(action.AttributeName, action.Value);
                    break;

                default:
                    throw new NotImplementedException("Action not implemented yet");

            }
        }
    }
}
