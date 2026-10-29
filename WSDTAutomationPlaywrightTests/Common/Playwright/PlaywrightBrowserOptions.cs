using Microsoft.Playwright;
using NUnit.Framework;
using System;
using PPCC2026.Common.Helper;

namespace PPCC2026.Common.Playwright;

public static class PlaywrightBrowserOptions
{
    public static BrowserTypeLaunchOptions GetLaunchOptions()
    {

        TestContext.Progress.WriteLine($"Playwright launch settings: " +
       $"Browser={TestConfig.BrowserType}, " +
       $"Headless={TestConfig.Headless}, " +
       $"BaseDirectory={AppContext.BaseDirectory}, " +
       $"EnvironmentOverride={Environment.GetEnvironmentVariable("Playwright__Headless") ?? "<not set>"}");


        BrowserTypeLaunchOptions launchOptions = new()
        {
            Headless = TestConfig.Headless,
            SlowMo = TestConfig.SlowMoMs,
            Args = !TestConfig.Headless &&string.Equals(TestConfig.BrowserType,"chromium",StringComparison.OrdinalIgnoreCase)
                ? new[] { "--start-maximized" }: null
        };

        if (!string.IsNullOrWhiteSpace(TestConfig.ExecutablePath))
        {
            launchOptions.ExecutablePath = TestConfig.ExecutablePath;
        }

        if (TestConfig.SelfHosted && !string.IsNullOrWhiteSpace(TestConfig.Proxy))
        {
            launchOptions.Proxy = new Proxy
            {
                Server = TestConfig.Proxy
            };
        }
        return launchOptions;
    }
}
