using Microsoft.Playwright;
using NUnit.Framework;
using System;
using PPCC2026.Common.Helper;
using Task = System.Threading.Tasks.Task;

namespace PPCC2026.Common;

public sealed class UciNavigation
{
    private readonly IPage page;
    private readonly string baseUrl;
    private readonly string? appId;
    private readonly string? appName;
    private readonly PopupHandler _popupHandler;
    private const int DefaultTimeout = 20_000;

    public UciNavigation(IPage page, string baseUrl, string? appId = null, string? appName = null)
    {
        this.page = page;
        this.baseUrl = baseUrl.TrimEnd('/');
        this.appId = string.IsNullOrWhiteSpace(appId) ? null : appId;
        this.appName = string.IsNullOrWhiteSpace(appName) ? null : appName;
        _popupHandler = new PopupHandler(page);
    }

    public async Task OpenRecordAsync(string entityLogicalName, Guid? recordId = null, string? stepName = null)
    {
        if (string.IsNullOrWhiteSpace(entityLogicalName))
        {
            throw new ArgumentException("Entity logical name must not be blank.", nameof(entityLogicalName));
        }

        string url = BuildRecordUrl(entityLogicalName, recordId);
        await page.GotoAsync(url, new PageGotoOptions
        {
            WaitUntil = WaitUntilState.DOMContentLoaded
        });
        TestContext.WriteLine("Registering popup handlers...");
        await _popupHandler.RegisterAsync();
        TestContext.WriteLine("Popup handlers registered.");
        await _popupHandler.HandleKnownPopupsAsync();
        await WaitForUciShellAsync();
        await WaitForRecordUrlAsync(entityLogicalName, recordId);
        await ThrowIfUciErrorVisibleAsync();
    }

    public async Task SelectOptionAsync(string comboboxName, string optionName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(comboboxName);
        ArgumentException.ThrowIfNullOrWhiteSpace(optionName);
        ILocator combo = page.GetByRole(AriaRole.Combobox, new PageGetByRoleOptions { Name = comboboxName });
        await combo.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = DefaultTimeout
        });
        await combo.ClickAsync();
        await page.GetByRole(
            AriaRole.Option,
            new PageGetByRoleOptions
            {
                Name = optionName,
                Exact = true
            })
            .ClickAsync(new LocatorClickOptions { Timeout = DefaultTimeout });
    }

    public async Task Chill(int milliseconds)
    {
        await page.WaitForTimeoutAsync(milliseconds);
    }

    public async Task SetTextAsync(string fieldName, string value)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(fieldName);
        ArgumentNullException.ThrowIfNull(value);
        ILocator field = page.GetByRole(AriaRole.Textbox, new PageGetByRoleOptions { Name = fieldName });
        await field.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = DefaultTimeout
        });

        await field.FillAsync(value, new LocatorFillOptions
        {
            Timeout = DefaultTimeout
        });


    }

    public async Task WaitForPageLoad()
    {
        await page.WaitForLoadStateAsync(LoadState.DOMContentLoaded);

        ILocator form = page.Locator(
            "div[data-id='editFormRoot'], " +
            "div[data-id='form-root'], " +
            "div[role='main']")
            .First;

        await form.WaitForAsync(new LocatorWaitForOptions
        {
            State = WaitForSelectorState.Visible,
            Timeout = 60_000
        });
    }

    public string BuildRecordUrl(string entityLogicalName, Guid? recordId = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(entityLogicalName);
        string baseUrl = TestConfig.OnlineCrmUrl?.Trim().TrimEnd('/');
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new InvalidOperationException(
                "TestConfig.OnlineCrmUrl is empty. " +
                "Check Environment:OnlineCrmUrl in the selected appsettings file.");
        }

        string recordUrl = $"{baseUrl}/main.aspx" +
            $"?pagetype=entityrecord" + $"&etn={Uri.EscapeDataString(entityLogicalName)}";

        recordUrl += recordId == null ? $"&id={recordId:D}" : string.Empty;

        TestContext.Out.WriteLine($"Selected environment: {TestConfig.SelectedEnvironment}");
        TestContext.Out.WriteLine($"Online CRM URL: {TestConfig.OnlineCrmUrl}");
        TestContext.Out.WriteLine($"Generated record URL: {recordUrl}");
        return recordUrl;
    }

    private async Task WaitForUciShellAsync()
    {
        await page.Locator("#shell-container, [data-id='navbar-container'], [data-id='appBreadCrumb']")
            .First.WaitForAsync(new LocatorWaitForOptions
            {
                State = WaitForSelectorState.Visible,
                Timeout = 60000
            });
    }

    private async Task WaitForRecordUrlAsync(string entityLogicalName, Guid? recordId)
    {
        string id = recordId.ToString();
        await page.WaitForURLAsync(
            url => url.Contains("pagetype=entityrecord", StringComparison.OrdinalIgnoreCase) &&
                url.Contains("etn=" + entityLogicalName, StringComparison.OrdinalIgnoreCase),
            //&& url.Contains(id, StringComparison.OrdinalIgnoreCase),
            new PageWaitForURLOptions
            {
                WaitUntil = WaitUntilState.DOMContentLoaded,
                Timeout = 60000
            });
    }

    private async Task ThrowIfUciErrorVisibleAsync()
    {
        ILocator errorDialog = page.Locator(
            "[data-id='errorDialog'], " +
            "[data-id='error-dialog'], " +
            "div[role='alertdialog'], " +
            "div[role='dialog']:has-text('Error')");

        if (await errorDialog.CountAsync() == 0)
        {
            return;
        }

        ILocator firstError = errorDialog.First;

        if (!await firstError.IsVisibleAsync())
        {
            return;
        }
        string message = await firstError.InnerTextAsync();
        throw new InvalidOperationException("UCI navigation error detected: " + message);
    }


}
