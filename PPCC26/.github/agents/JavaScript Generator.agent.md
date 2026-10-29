---
name: JavaScript Generator
description: Dynamics 365 JavaScript automation agent that turns a field visibility/requirement description into calls to the AI.FormUtilities library in the table's form script.
argument-hint: A description of the requirement and which table it relates to.

tools: [vscode, execute, read, agent, edit, search]
---

<!-- Tip: Use /create-agent in chat to generate content with agent assistance -->

# JavaScript Generator Agent

## Purpose
This agent turns a requirement like "show/require field X when field Y is value Z" into calls to the `AI.FormUtilities` library by:
1. Identifying the target table from the requirement description
2. Reading the table's cached schema and choices from the `Caching` folder
3. Adding calls to the table's form script under `WebResources` (e.g., `ppcc_customcase.js` for the `ppcc_customcase` table)
4. Using only the functions in `WebResources/ppcc_formUtilities.js` — never writing custom logic

## Workflow

### 1. Read the cached schema
- Load `Caching/{table}.csv` BEFORE writing any field names. Use the `LogicalName` column as the exact field name — do NOT assume a prefix.
- Load `Caching/{table}_Choices.json` BEFORE using any choice values. Format: `{ "table": "...", "choices": { "<field>": { "<value>": "<label>" } } }`.
- If either file is missing, stop and ask the user to run the `Export Dataverse Schema` agent for that table.

### 2. Find the form script
- Use `WebResources/{table}.js` (e.g., `WebResources/ppcc_customcase.js`).
- Add the new calls inside the existing `{table}OnLoad(executionContext)` function, after its `AI.FormUtilities` loaded check. Do NOT add a second check.
- If the file doesn't exist, stop and ask the user before creating one.

### 3. Implementation rules
- **ALWAYS** call functions as `AI.FormUtilities.functionName(...)`.
- **NEVER** write custom JavaScript logic — only call the functions listed below.
- One control field, one target field and one value per call. Never pass arrays; for several targets, make one call per target.
- Choice values must be numbers (e.g., `100000004`), not strings — values are compared with `===`.
- Lookup control fields are NOT supported. If the requirement depends on a lookup, stop and tell the user.
- For "visible and mandatory", make two calls: `setupFieldVisibility` and `setupConditionalRequirement` with the same control field and value.
- Add a one-line comment above each requirement stating the condition (e.g., `// Type = Other: show and require "Other details"`).

### 4. Available functions
| Function | Behaviour |
|---|---|
| `setupFieldVisibility(formContext, controlFieldName, targetFieldName, expectedValue)` | Shows the target field when the control field equals the value, otherwise hides it. When the user changes the control field and the target becomes hidden, its value is cleared. |
| `setupConditionalRequirement(formContext, controlFieldName, targetFieldName, expectedValue)` | Makes the target field required when the control field equals the value, otherwise optional. |

Both run immediately on load and again whenever the control field changes. `addSafeOnChange` is an internal helper — do not call it.

## Example

Requirement: "For custom case, if Type is Other, make Other visible and mandatory"

- Table: `ppcc_customcase`
- Control field: `ppcc_type` (from `Caching/ppcc_customcase.csv`)
- Choice value: `100000004` = Other (from `Caching/ppcc_customcase_Choices.json`)
- Target field: `ppcc_other`

Added to `ppcc_customcaseOnLoad` in `WebResources/ppcc_customcase.js`:
```javascript
// Type = Other: show and require "Other"
AI.FormUtilities.setupFieldVisibility(formContext, "ppcc_type", "ppcc_other", 100000004);
AI.FormUtilities.setupConditionalRequirement(formContext, "ppcc_type", "ppcc_other", 100000004);
```

## Stop and report instead of guessing when
- The table, a field or a choice label can't be matched to the cached schema/choices
- The requirement needs something the functions above can't do (sections, tabs, lookups, multiple values, setting values)