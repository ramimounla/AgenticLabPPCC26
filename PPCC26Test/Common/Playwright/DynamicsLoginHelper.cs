using Microsoft.Playwright;
using NUnit.Framework;
using System;
using System.IO;
using System.Threading.Tasks;
using PPCC2026.Common.Helper;
using PPCC2026.Model;

namespace PPCC2026.Common.Playwright;

public static class DynamicsLoginHelper
{
    private const int DefaultTimeout = 60_000;
    private const int OptionalPromptTimeout = 5_000;
    private const string DynamicsShellSelector = "#shell-container, [data-id='navbar-container']";
    private static async Task<bool> IsAlreadyLoggedInAsync(IPage page)
    {
        ArgumentNullException.ThrowIfNull(page);
        ILocator shell = page.Locator(DynamicsShellSelector).First;
        try
        {
            await shell.WaitForAsync(new LocatorWaitForOptions
                {
                    State = WaitForSelectorState.Visible,
                    Timeout = OptionalPromptTimeout
                });
            return true;
        }
        catch (TimeoutException)
        {
            return false;
        }
    }
    public static async Task LoginAsync(IPage page,UserDTO user)
    {
        ArgumentNullException.ThrowIfNull(page);
        ArgumentNullException.ThrowIfNull(user);
        if (string.IsNullOrWhiteSpace(TestConfig.OnlineCrmUrl))
        {
            throw new InvalidOperationException("Environment:OnlineCrmUrl is not configured in appsettings.json.");
        }

        if (string.IsNullOrWhiteSpace(user.Username))
        {
            throw new InvalidOperationException("Cannot log in because username is blank.");
        }

        if (string.IsNullOrWhiteSpace(user.Password))
        {
            throw new InvalidOperationException("Cannot log in because password is blank.");
        }

        TestContext.Out.WriteLine($"Starting Dynamics login for '{user.Username}'.");
        await page.GotoAsync(TestConfig.OnlineCrmUrl,new PageGotoOptions
            {
                WaitUntil = WaitUntilState.DOMContentLoaded,
                Timeout = DefaultTimeout
            });

        if (await IsAlreadyLoggedInAsync(page))
        {
            TestContext.Out.WriteLine("The existing browser session is already authenticated.");
            await WaitForDynamicsShellAsync(page);
            return;
        }

        await EnterUsernameAsync(page,user.Username);
        await EnterPasswordAsync(page,user.Password);
        await HandleStaySignedInPromptIfVisibleAsync(page);
        await WaitForDynamicsShellAsync(page);
        TestContext.Out.WriteLine($"Dynamics login completed for '{user.Username}'.");
    }

    public static async Task WaitForDynamicsShellAsync(IPage page)
    {
        ArgumentNullException.ThrowIfNull(page);
        try
        {
            await page.Locator(DynamicsShellSelector).WaitForAsync(
                new LocatorWaitForOptions
                {
                    State = WaitForSelectorState.Visible,
                    Timeout = DefaultTimeout
                });
        }
        catch (TimeoutException)
        {
            await CaptureLoginDiagnosticsAsync(page, "dynamics-shell-timeout");
            throw new TimeoutException(
                $"Timed out waiting for Dynamics shell. Current URL incorrect");
        }
    }

    private static async Task EnterUsernameAsync(IPage page, string username)
    {
        ILocator emailInput = page.Locator("input[type='email'], input[name='loginfmt']").First;
        await emailInput.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = DefaultTimeout
        });

        await emailInput.FillAsync(username);
        await ClickButtonAsync(page, "Next", "#idSIButton9");
        await WaitForPasswordPageAsync(page);
    }

   
    private static async Task WaitForPasswordPageAsync(IPage page)
    {
        ILocator passwordInput = GetPasswordInput(page);
        try
        {
            await Assertions.Expect(passwordInput)
                .ToBeVisibleAsync(
                    new LocatorAssertionsToBeVisibleOptions
                    {
                        Timeout = DefaultTimeout
                    });

            await Assertions.Expect(passwordInput)
                .ToBeEditableAsync(
                    new LocatorAssertionsToBeEditableOptions
                    {
                        Timeout = DefaultTimeout
                    });
        }
        catch (PlaywrightException)
        {
            await CaptureLoginDiagnosticsAsync(page,"password-page-timeout");

            throw new TimeoutException($"The password field did not become visible. Current URL: '{page.Url}'.");
        }
    }

    private static async Task EnterPasswordAsync(IPage page,string password)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(password);
        ILocator passwordInput = GetPasswordInput(page);
        await Assertions.Expect(passwordInput)
            .ToBeVisibleAsync(new LocatorAssertionsToBeVisibleOptions
                {
                    Timeout = DefaultTimeout
                });

        await Assertions.Expect(passwordInput).ToBeEditableAsync(
                new LocatorAssertionsToBeEditableOptions
                {
                    Timeout = DefaultTimeout
                });       
        passwordInput = GetPasswordInput(page);

        await passwordInput.FillAsync(password,
            new LocatorFillOptions
            {
                Timeout = DefaultTimeout
            });

        await Assertions.Expect(passwordInput).ToHaveValueAsync(password,
                new LocatorAssertionsToHaveValueOptions
                {
                    Timeout = 10_000
                });

        TestContext.Out.WriteLine($"Password populated successfully. Character count: {password.Length}.");
        await ClickButtonAsync(
            page,
            "Sign in",
            "#idSIButton9");
    }

    
    private static async Task HandleStaySignedInPromptIfVisibleAsync(IPage page)
    {
        ILocator yesButton = page.GetByRole(AriaRole.Button,new PageGetByRoleOptions { Name = "Yes" });
        try
        {
            await yesButton.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = OptionalPromptTimeout
            });
            await yesButton.ClickAsync();
            TestContext.Out.WriteLine("Clicked 'Yes' on Stay signed in prompt.");
        }
        catch (TimeoutException)
        {
            TestContext.Out.WriteLine("Stay signed in prompt did not appear.");
        }
    }

    private static async Task ClickButtonAsync(IPage page,string buttonName,string fallbackSelector)
    {
        ILocator namedButton = page.GetByRole(AriaRole.Button,new PageGetByRoleOptions { Name = buttonName });
        if (await namedButton.CountAsync() > 0)
        {
            var button = namedButton.First;
            if (await button.IsVisibleAsync() &&await button.IsEnabledAsync())
            {
                await button.ClickAsync(new()
                {
                    Timeout = OptionalPromptTimeout
                });
                return;
            }
        }

        var nextButton = page.Locator(fallbackSelector);      
        await page.Locator(fallbackSelector).ClickAsync(new LocatorClickOptions
        {
            Timeout = DefaultTimeout
        });
    }

    private static async Task CaptureLoginDiagnosticsAsync(IPage page, string reason)
    {
        string diagnosticsFolder = Path.Combine(TestContext.CurrentContext.WorkDirectory,"login-diagnostics");
        Directory.CreateDirectory(diagnosticsFolder);
        string safeReason = reason.Replace(" ", "-", StringComparison.OrdinalIgnoreCase);
        string screenshotPath = Path.Combine(diagnosticsFolder, $"{safeReason}.png");
        string htmlPath = Path.Combine(diagnosticsFolder, $"{safeReason}.html");
        await page.ScreenshotAsync(new PageScreenshotOptions
        {
            Path = screenshotPath,
            FullPage = true
        });

        string html = await page.ContentAsync();
        await File.WriteAllTextAsync(htmlPath, html);
        TestContext.Out.WriteLine($"Login diagnostic screenshot: {screenshotPath}");
        TestContext.Out.WriteLine($"Login diagnostic HTML: {htmlPath}");

    }
    public static async Task WaitForDynamicsReadyAsync(IPage page)
    {
        await page.WaitForLoadStateAsync(LoadState.DOMContentLoaded);
        ILocator shell = page.Locator("div[data-id='appBreadCrumb'], div[data-id='navbar-container'], div[role='main']");

        try
        {
            await shell.First.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = 60_000
            });
        }
        catch
        {
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);
        }
    }
       
    private static ILocator GetPasswordInput(IPage page)
    {
        return page.Locator(
             "input#i0118[name='passwd'][type='password']" +
             ":not([aria-hidden='true'])" +
             ":not(.moveOffScreen)" +
             "[tabindex='0']");
    }

}
