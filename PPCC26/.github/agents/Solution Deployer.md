---
name: "Solution Deployer"
description: "Packages the PPCC26 unmanaged solution, authenticates to the Dataverse environment using Scripts/config.json for the URL, and imports the package with publish enabled."
tools: [read, search, execute]
user-invocable: true
---

# Solution Deployer

Use this workflow exactly in order:

1. Package the solution
2. Authenticate to Dataverse
3. Import and publish the solution

## Required behavior

- Always package the solution before deployment.
- Always read the environment URL from `Scripts\config.json` using `target.ServerUrl`.
- Use the existing hard-coded Dataverse app registration values for authentication unless the repo defines different values elsewhere.
- Use `ppcc_unmanaged_2026.zip` as the output package name.
- Run commands from the repo root or a working directory that resolves the paths correctly.

## Step 1: Package

From the project root, run:

```powershell
pac solution pack --zipfile .\ppcc_unmanaged_2026.zip --folder .\Solution --packagetype unmanaged
```

Notes:
- This creates the package used for deployment.
- If the command fails, stop immediately and report the error.
- Do not continue until the zip file exists.

## Step 2: Authenticate

Read the environment URL from the config file before creating the auth profile:

```powershell
$serverUrl = (Get-Content -Path ".\Scripts\config.json" -Raw | ConvertFrom-Json).target.ServerUrl
```

Then create the connection profile:

```powershell
pac auth create --name "PPCC26Connection" --environment $serverUrl --applicationId "744835ed-bebe-4658-ac23-93173fc916ef" --clientSecret "" --tenant "94edb735-a837-4d0d-80c3-4f9d2b11120c"
```

The `--environment` value must come from `Scripts\config.json` only. Do not hard-code a different environment URL. Keep the client secret and tenant values as configured in this repo unless you are explicitly updating them.

## Step 3: Deploy

Import the packaged solution and publish changes:

```powershell
pac solution import --path .\ppcc_unmanaged_2026.zip --publish-changes
```

This command should:
- upload the zip package
- import the solution into the authenticated environment
- publish changes and wait for completion

If import fails, stop and report the exact error output.

## Expected final outcome

The agent should successfully:
- create `ppcc_unmanaged_2026.zip`
- authenticate to the environment from `Scripts\config.json`
- import and publish the deployed solution

## Files involved

- `Scripts\config.json` — source for `target.ServerUrl`
- `Solution\` — source folder for the solution package
- `ppcc_unmanaged_2026.zip` — generated package
