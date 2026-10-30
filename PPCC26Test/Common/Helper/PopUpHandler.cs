using Microsoft.Playwright;
using NUnit.Framework;
using System;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace PPCC2026.Common.Helper
{
    public class PopupHandler
    {
        private readonly IPage _page;
        private bool _registered;
        public PopupHandler(IPage page)
        {
            _page = page ?? throw new ArgumentNullException(nameof(page));
        }

        public async Task RegisterAsync()
        {
            if (_registered)
            {
                return;
            }
            await RegisterReleaseNotesPopupAsync();
            await RegisterDuplicateDialogAsync();
            await RegisterGotItPopupAsync(); 

            _registered = true;
            TestContext.Progress.WriteLine("Popup handlers registered.");
        }

        public async Task HandleKnownPopupsAsync()
        {
            for (var attempt = 0; attempt < 3; attempt++)
            {
                var handledAny = false;
                handledAny |= await CloseReleaseNotesIfVisibleAsync();
                handledAny |= await ClickIfVisibleAsync(
                    _page.Locator("button[data-id='okButton']").Filter(new()
                    {
                        HasTextString = "Sign In"
                    }),
                    "Sign-in popup by data-id");
                handledAny |= await ClickIfVisibleAsync(
                    _page.Locator("#defaultDialogChromeCloseIconButton-1"),
                    "Release notes close button by id");
                handledAny |= await ClickIfVisibleAsync(
                    _page.Locator("button[data-id='dialogCloseIconButton']"),
                    "Release notes close button by data-id");
                handledAny |= await CloseDuplicateDialogIfVisibleAsync();
                handledAny |= await ClickIfVisibleAsync(
                    _page.GetByRole(AriaRole.Button, new() { Name = "Got it" }),
                    "Got it popup");          

                if (!handledAny)
                {
                    return;
                }
                await _page.WaitForTimeoutAsync(500);
            }
        }
        private async Task<bool> CloseDuplicateDialogIfVisibleAsync()
        {
            ILocator duplicateDialogs = _page.GetByRole(AriaRole.Dialog).Filter(new LocatorFilterOptions
                {
                    HasTextRegex = new Regex("duplicate|duplicates detected|" +
                        "duplicate records|potential duplicate",
                        RegexOptions.IgnoreCase)
                });
            int count = await duplicateDialogs.CountAsync();
            for (int index = 0; index < count; index++)
            {
                ILocator dialog = duplicateDialogs.Nth(index);
                if (!await dialog.IsVisibleAsync())
                {
                    continue;
                }

                ILocator closeButton = dialog
                    .Locator("button[data-id='dialogCloseIconButton']")
                    .Or(dialog.GetByRole(AriaRole.Button,new LocatorGetByRoleOptions
                            {
                                NameRegex = new Regex("close", RegexOptions.IgnoreCase)
                            }))
                    .First;

                if (await closeButton.CountAsync() == 0)
                {
                    return false;
                }
                await SafeClickAsync(closeButton,"Duplicate dialog");
                return true;
            }

            return false;
        }
        private async Task<bool> CloseReleaseNotesIfVisibleAsync()
        {
            ILocator releaseNotesDialog = _page.Locator("[role='dialog']",new PageLocatorOptions
                {
                    HasTextRegex = new Regex("release notes|what'?s new",RegexOptions.IgnoreCase)
                });
            if (await releaseNotesDialog.CountAsync() == 0)
            {
                return false;
            }
            ILocator visibleDialog =releaseNotesDialog.First;
            if (!await visibleDialog.IsVisibleAsync())
            {
                return false;
            }
            ILocator closeButton = visibleDialog.Locator("button[data-id='dialogCloseIconButton']").First;

            if (await closeButton.CountAsync() == 0)
            {
                return false;
            }
            await SafeClickAsync(closeButton,"Release notes popup");
            return true;
        }
       
        private async Task RegisterReleaseNotesPopupAsync()
        {
            ILocator releaseNotesDialog = _page.GetByRole(AriaRole.Dialog, new PageGetByRoleOptions
                    {
                        NameRegex = new Regex("release notes|what'?s new",RegexOptions.IgnoreCase)
                    }).Or(_page.Locator("[role='dialog']", new PageLocatorOptions
                        {
                            HasTextRegex = new Regex("release notes|what'?s new",RegexOptions.IgnoreCase)
                        }));
            await _page.AddLocatorHandlerAsync(releaseNotesDialog,async dialog =>
                {
                    TestContext.Progress.WriteLine("Release notes popup detected automatically.");
                    ILocator closeButton = dialog.Locator("button[data-id='dialogCloseIconButton']")
                        .Or(
                            dialog.GetByRole(AriaRole.Button,new LocatorGetByRoleOptions
                                {
                                    NameRegex = new Regex("close",RegexOptions.IgnoreCase)
                                }))
                        .First;
                    if (await closeButton.CountAsync() > 0 && await closeButton.IsVisibleAsync())
                    {
                        await SafeClickAsync(closeButton,"Release notes popup");
                    }
                });
        }
        private async Task RegisterDuplicateDialogAsync()
        {
            ILocator duplicateDialog = _page.GetByRole(AriaRole.Dialog).Filter(new LocatorFilterOptions
                {
                    HasTextRegex = new Regex("duplicate|duplicates detected|" +
                        "duplicate records|potential duplicate",
                        RegexOptions.IgnoreCase)
                });

            await _page.AddLocatorHandlerAsync(duplicateDialog,async dialog =>
                {
                    TestContext.Progress.WriteLine("Duplicate dialog detected automatically.");
                    ILocator closeButton = dialog
                        .Locator("button[data-id='dialogCloseIconButton']")
                        .Or(dialog.GetByRole(AriaRole.Button,new LocatorGetByRoleOptions
                                {
                                    NameRegex = new Regex("close", RegexOptions.IgnoreCase)
                                })).First;

                    if (await closeButton.CountAsync() == 0)
                    {
                        TestContext.Progress.WriteLine("Duplicate dialog was detected, but its close button was not found.");
                        return;
                    }
                    await SafeClickAsync(closeButton,"Duplicate dialog");
                });
        }

        private async Task RegisterGotItPopupAsync()
        {
            var gotItButton = _page.GetByRole(AriaRole.Button, new() { Name = "Got it" })
                .Or(_page.Locator("button[class*='fui-TeachingPopoverFooter__secondary']"));

            await _page.AddLocatorHandlerAsync(gotItButton, async locator =>
            {
                TestContext.Progress.WriteLine("Got it popup detected automatically.");
                await SafeClickAsync(locator, "Got it popup");
            });
        }

        private static async Task<bool> ClickIfVisibleAsync(ILocator locator,string popupName)
        {
            try
            {
                ILocator first = locator.First;
                if (await first.CountAsync() == 0 ||
                    !await first.IsVisibleAsync())
                {
                    return false;
                }

                TestContext.Progress.WriteLine($"{popupName} visible. Clicking.");
                await SafeClickAsync(first, popupName);
                return true;
            }
            catch (PlaywrightException exception)
            {
                TestContext.Progress.WriteLine($"Unable to handle popup '{popupName}': {exception.Message}");
                return false;
            }
        }

        private static async Task SafeClickAsync(ILocator locator, string popupName)
        {
            try
            {
                await locator.ClickAsync(new LocatorClickOptions
                {
                    Timeout = 3000
                });
                TestContext.Progress.WriteLine($"Popup closed: {popupName}");              
            }
            catch
            {
                await locator.ClickAsync(new LocatorClickOptions
                {
                    Timeout = 3000,
                    Force = true
                });
                TestContext.Progress.WriteLine($"{popupName} required force click.");
            }
        }
    }
}
