#Requires -Version 5.1
#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Exports all choice values (Picklist and MultiSelectPicklist) from a Dataverse table to a JSON file.

.DESCRIPTION
    This script reads the metadata of a specified Dataverse table and extracts all choice-type fields
    (single-select Picklist and MultiSelectPicklist). For each choice field, it lists all available
    options (value and label). Optionally, it can include Status/State choices and Boolean fields.

.PARAMETER TableName
    The logical name of the table to export choices for.

.PARAMETER OutputPath
    Optional. The path where the JSON file will be saved. If not specified, will save to the current
    directory with filename: {TableName}_Choices_{timestamp}.json

.PARAMETER IncludeStateStatus
    Optional. If $true, includes Status and State attributes in the export. Default is $false.

.PARAMETER IncludeBoolean
    Optional. If $true, includes Boolean attributes (True/False labels) in the export. Default is $false.

.PARAMETER LocaleId
    Optional. The language code (LCID) to use for option labels (e.g., 1033 for en-US). Default is 1033.

.EXAMPLE
    .\Export-DataverseChoices.ps1 -TableName "account" -OutputPath "C:\\Export\\account_choices.json"

.EXAMPLE
    .\Export-DataverseChoices.ps1 -TableName "ppcc_p2ecase" -IncludeStateStatus $true -IncludeBoolean $true

.NOTES
    Requires the Microsoft.PowerApps.Administration.PowerShell and Microsoft.Xrm.Data.PowerShell modules.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TableName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeStateStatus = $false,

    [Parameter(Mandatory = $false)]
    [bool]$IncludeBoolean = $false,

    [Parameter(Mandatory = $false)]
    [int]$LocaleId = 1033
)

# Import common functions from DataverseCommon module
Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

function Get-TableMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        
        [Parameter(Mandatory = $true)]
        [string]$TableLogicalName
    )

    Write-Host "Retrieving metadata for table '$TableLogicalName'..." -ForegroundColor Yellow
    
    try {
        $request = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveEntityRequest
        $request.LogicalName = $TableLogicalName
        $request.EntityFilters = [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Attributes
        $request.RetrieveAsIfPublished = $true
        
        $response = $Connection.Execute($request)
        
        if ($null -ne $response) {
            Write-Host "Retrieved metadata for table '$TableLogicalName' with $(($response.EntityMetadata.Attributes | Measure-Object).Count) attributes." -ForegroundColor Green
            return $response.EntityMetadata
        }
        else {
            throw "Failed to retrieve metadata for table '$TableLogicalName'"
        }
    }
    catch {
        Write-Error "Error retrieving metadata for table '$TableLogicalName': $_"
        throw
    }
}

function Get-UserLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Sdk.Label]$Label,
        
        [Parameter(Mandatory = $true)]
        [int]$LocaleId
    )

    if ($Label -and $Label.UserLocalizedLabel -and $Label.UserLocalizedLabel.Label) {
        return $Label.UserLocalizedLabel.Label
    }
    elseif ($Label -and $Label.LocalizedLabels -and $Label.LocalizedLabels.Count -gt 0) {
        $match = $Label.LocalizedLabels | Where-Object { $_.LanguageCode -eq $LocaleId } | Select-Object -First 1
        if ($match) { return $match.Label }
        return $Label.LocalizedLabels[0].Label
    }
    return ""
}

function Get-OptionSetOptions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        
        [Parameter(Mandatory = $true)]
        [string]$OptionSetName
    )

    try {
        $req = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveOptionSetRequest
        $req.Name = $OptionSetName
        $req.RetrieveAsIfPublished = $true
        $resp = $Connection.Execute($req)
        if ($resp -and $resp.OptionSetMetadata) {
            return $resp.OptionSetMetadata.Options
        }
        return $null
    }
    catch {
        Write-Verbose "Failed to retrieve global option set '$OptionSetName': $_"
        return $null
    }
}

function ConvertTo-ChoiceRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Sdk.Metadata.EntityMetadata]$EntityMetadata,
        
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        
        [Parameter(Mandatory = $true)]
        [int]$LocaleId,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeStateStatus = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeBoolean = $false
    )

    Write-Host "Extracting choice values from attributes..." -ForegroundColor Yellow

    # Build hierarchical structure: { table, choices: { fieldLogicalName: { optionValue: optionLabel } } }
    $choices = @{}
    $totalOptions = 0

    foreach ($attr in $EntityMetadata.Attributes) {
        $type = $attr.AttributeType.ToString()
        $isPicklist = ($type -eq 'Picklist')
        $isMulti = ($type -eq 'MultiSelectPicklist')
        $isStatus = ($type -eq 'Status')
        $isState = ($type -eq 'State')
        $isBoolean = ($type -eq 'Boolean')

        if (-not ($isPicklist -or $isMulti -or ($IncludeStateStatus -and ($isStatus -or $isState)) -or ($IncludeBoolean -and $isBoolean))) {
            continue
        }

        $fieldLogicalName = $attr.LogicalName
        $options = @()

        if ($isBoolean) {
            $boolAttr = [Microsoft.Xrm.Sdk.Metadata.BooleanAttributeMetadata]$attr
            if ($boolAttr.OptionSet) {
                $trueOpt = $boolAttr.OptionSet.TrueOption
                $falseOpt = $boolAttr.OptionSet.FalseOption
                if ($trueOpt) { $options += $trueOpt }
                if ($falseOpt) { $options += $falseOpt }
            }
        }
        else {
            if ($attr.OptionSet) {
                $optionSetName = $attr.OptionSet.Name
                $isGlobal = [bool]$attr.OptionSet.IsGlobal
                if ($isGlobal -and $optionSetName) {
                    $globalOptions = Get-OptionSetOptions -Connection $Connection -OptionSetName $optionSetName
                    if ($null -ne $globalOptions) { $options = $globalOptions } else { $options = $attr.OptionSet.Options }
                }
                else {
                    $options = $attr.OptionSet.Options
                }
            }
        }

        if ($options -and $options.Count -gt 0) {
            $optMap = @{}
            foreach ($opt in $options) {
                if ($null -eq $opt) { continue }
                $label = if ($opt.Label) { Get-UserLabel -Label $opt.Label -LocaleId $LocaleId } else { "" }
                $value = $opt.Value
                # Ensure keys are strings in JSON
                $key = if ($null -ne $value) { $value.ToString() } else { "" }
                $optMap[$key] = $label
            }
            $choices[$fieldLogicalName] = $optMap
            $totalOptions += ($optMap.Keys | Measure-Object).Count
        }
    }

    Write-Host "Extracted $((($choices.Keys | Measure-Object).Count)) choice fields with $totalOptions total options." -ForegroundColor Green

    return [PSCustomObject]@{
        table   = $EntityMetadata.LogicalName
        choices = $choices
    }
}

function Export-ChoicesToJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Data,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-Host "Exporting choices to JSON: '$FilePath'" -ForegroundColor Yellow
    try {
        $directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Write-Host "Created directory: $directory" -ForegroundColor Green
        }
        $json = $Data | ConvertTo-Json -Depth 8
        $json | Out-File -FilePath $FilePath -Encoding utf8
        # Count summary
        $fieldCount = ($Data.choices.Keys | Measure-Object).Count
        $optionCount = ($Data.choices.GetEnumerator() | ForEach-Object { ($_.Value.Keys | Measure-Object).Count } | Measure-Object -Sum).Sum
        Write-Host "Export complete. Fields: $fieldCount, Total options: $optionCount" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to export JSON: $_"
        throw
    }
}

function Show-Summary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Data,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TableName
    )

    Write-Host "`n=== Choice Export Summary ===" -ForegroundColor Cyan
    Write-Host "Table: $TableName" -ForegroundColor White
    Write-Host "Output file: $FilePath" -ForegroundColor White
    $fieldCount = ($Data.choices.Keys | Measure-Object).Count
    $optionCount = ($Data.choices.GetEnumerator() | ForEach-Object { ($_.Value.Keys | Measure-Object).Count } | Measure-Object -Sum).Sum
    Write-Host "Fields exported: $fieldCount" -ForegroundColor White
    Write-Host "Total options exported: $optionCount" -ForegroundColor White

    $fieldCounts = @()
    foreach ($kv in $Data.choices.GetEnumerator()) {
        $fieldCounts += [PSCustomObject]@{ Name = $kv.Key; Count = ($kv.Value.Keys | Measure-Object).Count }
    }
    $fieldCounts = $fieldCounts | Sort-Object Count -Descending
    Write-Host "`nTop fields by option count:" -ForegroundColor Yellow
    foreach ($g in $fieldCounts | Select-Object -First 10) {
        Write-Host " - $($g.Name): $($g.Count) options" -ForegroundColor White
    }
}

# Main script execution
try {
    # Import required modules from common module
    Import-RequiredModules

    # Connect to Dataverse
    $connection = Connect-ToDataverse

    # Check if the table exists
    if (-not (Test-TableExists -TableLogicalName $TableName)) {
        Write-Error "The specified table '$TableName' does not exist in Dataverse."
        exit 1
    }

    # Generate output path if not specified
    if ([string]::IsNullOrEmpty($OutputPath)) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputPath = Join-Path -Path (Get-Location) -ChildPath "$($TableName)_Choices_$timestamp.json"
    }

    # Get table metadata
    $entityMetadata = Get-TableMetadata -Connection $connection -TableLogicalName $TableName

    # Build hierarchical data
    $data = ConvertTo-ChoiceRows -EntityMetadata $entityMetadata -Connection $connection -LocaleId $LocaleId -IncludeStateStatus $IncludeStateStatus -IncludeBoolean $IncludeBoolean

    # Export
    Export-ChoicesToJson -Data $data -FilePath $OutputPath

    # Summary
    Show-Summary -Data $data -FilePath $OutputPath -TableName $TableName

    Write-Host "`nOperation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
