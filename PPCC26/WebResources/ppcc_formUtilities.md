# AI.FormUtilities

[ai_formUtilities.js](ai_formUtilities.js) is a set of reusable helpers for Dataverse / Dynamics 365 model-driven form scripts.

- Every function takes the form's `formContext` as its first argument.
- Each `setup*` function applies its rule straight away and re-applies it whenever the watched field changes.
- All functions are available as `AI.FormUtilities.*`.
- Lookup IDs (GUIDs) are compared ignoring case and `{}` braces.
- Errors are logged to the browser console, so a missing field doesn't break the form.

## Show or hide fields

| Function | Purpose |
|---|---|
| `setupFieldVisibility` | Shows or hides one or more fields based on a control field (a specific value, several values, a lookup ID, or any value at all). Hidden fields are made optional and their original requirement is restored when shown again |
| `setupPolymorphicFieldVisibility` | Shows or hides fields based on which table a multi-table lookup (e.g. `regardingobjectid`) points to |
| `setupDateConditionalVisibility` | Shows or hides fields by comparing a date field with another date using `<`, `<=`, `=`, `!=`, `>=` or `>` |

## Make fields required or optional

| Function | Purpose |
|---|---|
| `setupConditionalRequirement` | Makes one or more fields required or optional based on a control field's value |
| `setupDateConditionalRequirement` | Makes a field required based on a date comparison |
| `setupMultiFieldConditionalRequirement` | Makes a field required only when several conditions are all true |

## Combined or custom rules

| Function | Purpose |
|---|---|
| `setupFunctionBasedConditional` | Runs your own check function when chosen fields change, then shows/hides or requires the target fields |
| `setupDateVsDueDateConditional` | Built-in overdue rule: shows or requires fields when a tracked date is empty past its due date, or was filled in after the due date |

## Helper

| Function | Purpose |
|---|---|
| `addSafeOnChange` | Adds an on-change handler to a field without removing existing ones, and can optionally run it straight away |

## Example

```javascript
function onLoad(executionContext) {
    var formContext = executionContext.getFormContext();

    AI.FormUtilities.setupFieldVisibility(
        formContext,
        "ai_agecategory",              // Control field
        "ai_adultnotes",               // Field to show/hide
        100000004                      // Expected value: Adult
    );

    AI.FormUtilities.setupConditionalRequirement(
        formContext,
        "ai_agecategory",              // Control field
        "ai_guardianname",             // Field to make required
        [100000002, 100000003]         // Expected values: Child, Youth
    );
}
```
