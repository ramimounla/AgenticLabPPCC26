using Microsoft.Extensions.Configuration;
using System;
using System.IO;

namespace PPCC2026.Common.Helper
{
    public static class TestConfig
    {
        private static readonly IConfigurationRoot config = Build();

        private static IConfigurationRoot Build()
        {
            string configPath = Path.Combine(AppContext.BaseDirectory, "Config");         
            IConfigurationRoot selectorConfig = new ConfigurationBuilder()
                .SetBasePath(configPath)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: false)
                .AddJsonFile("appsettings.local.json", optional: true, reloadOnChange: false)
                .AddEnvironmentVariables()
                .Build();

            string selectedEnvironment =
                selectorConfig["Configuration:SelectedEnvironment"]
                ?? selectorConfig["TEST_ENVIRONMENT"]
                ?? selectorConfig["DOTNET_ENVIRONMENT"]
                ?? "";

            /*           
             * Load the final config in the intended order.           
             * appsettings.json then
             * appsettings.{SelectedEnvironment}.json then
             * appsettings.local.json then
             * environment variables         
             * appsettings.local.json is loaded again so local file values can override
             * shared values if needed.
             */
            IConfigurationBuilder builder = new ConfigurationBuilder()
                .SetBasePath(configPath)
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: false);

            if (!string.IsNullOrWhiteSpace(selectedEnvironment))
            {
                builder.AddJsonFile(
                    $"appsettings.{selectedEnvironment}.json",
                    optional: true,
                    reloadOnChange: false);
            }

            builder
                .AddJsonFile("appsettings.local.json", optional: true, reloadOnChange: false)
                .AddEnvironmentVariables();
            return builder.Build();
        }

        // Runtime 
        public static string SelectedEnvironment => config["Configuration:SelectedEnvironment"]
            ?? "";

        // Environment
        public static string OnlineCrmUrl => config["Environment:OnlineCrmUrl"] ?? "";

        //UserDTO Access
        public static string Username => config["Authentication:Username"] ?? "";
        public static string Password => config["Authentication:Password"] ?? "";
        public static string AppId => config["Environment:AppId"] ?? "";
        public static string AppName => config["Environment:AppName"] ?? "";

        //Network 
        public static bool SelfHosted =>bool.TryParse(config["Network:SelfHosted"], out bool b) && b;
        public static string Proxy =>config["Network:Proxy"] ?? "";       

        // Playwright
        public static string BrowserType => config["Playwright:Browser"] ?? "chromium";
        public static bool Headless => bool.TryParse(config["Playwright:Headless"], out bool value)? value: true;
        public static int SlowMoMs =>  int.TryParse(config["Playwright:SlowMoMs"], out int value)? value: 0;
        public static string ExecutablePath => config["Playwright:ExecutablePath"] ?? "";
        public static bool UsePrivateMode => bool.TryParse(config["Playwright:UsePrivateMode"], out bool value)&& value;
        public static int ViewportWidth =>int.TryParse(config["Playwright:ViewportWidth"],out int value)? value: 1920;
        public static int ViewportHeight =>int.TryParse(config["Playwright:ViewportHeight"],out int value)? value: 1080;
        // --- Portal URLs      
        public static string Get(string key) =>config[key] ?? "";    
     
    }
}
