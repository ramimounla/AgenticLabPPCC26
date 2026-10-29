#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Adds a choice field to a table in Dataverse.

.DESCRIPTION
    This script adds a choice (picklist) field to a specified table, backed by either a global choice option set
    that can be reused across tables, or a local option set scoped to the field only.
    It supports both single-select and multi-select choice fields.

.PARAMETER TableName
    The logical name of the table to add the field to.

.PARAMETER ChoiceDisplayName
    The display name of the choice field.

.PARAMETER ChoiceSchemaName
    The schema name of the choice field.

.PARAMETER GlobalChoiceName
    The name of the global choice option set. Required only when -IsGlobal is $true.

.PARAMETER IsGlobal
    Specifies whether to create a reusable global choice option set ($true, default) or a local option set scoped to this field only ($false).

.PARAMETER ChoiceValues
    A comma-separated list of values to add to the choice.

.PARAMETER SolutionName
    Optional. The unique name of the solution to add the choice field to. If not specified, the field will be created in the default solution.

.PARAMETER IsMandatory
    Specifies whether the field is mandatory. Default is $false.

.PARAMETER IsAudited
    Specifies whether the field is audited. Default is $false.

.PARAMETER IsMultiSelect
    Optional. Specifies whether the choice field supports multiple selections. Default is $false.

.EXAMPLE
    .\Add-DataverseChoiceField.ps1 -TableName "account" -ChoiceDisplayName "Account Category" -ChoiceSchemaName "new_AccountCategory" -GlobalChoiceName "new_AccountCategoryType" -ChoiceValues "Premium,Standard,Basic" -IsMandatory $false -IsAudited $true

.EXAMPLE
    .\Add-DataverseChoiceField.ps1 -TableName "contact" -ChoiceDisplayName "Contact Type" -ChoiceSchemaName "new_ContactType" -GlobalChoiceName "new_ContactTypeValues" -ChoiceValues "Customer,Partner,Vendor" -SolutionName "MyCustomSolution" -IsMandatory $true -IsAudited $true

.EXAMPLE
    .\Add-DataverseChoiceField.ps1 -TableName "account" -ChoiceDisplayName "Services Required" -ChoiceSchemaName "new_ServicesRequired" -GlobalChoiceName "new_ServicesRequiredValues" -ChoiceValues "Consulting,Implementation,Support,Training" -SolutionName "MyCustomSolution" -IsMultiSelect $true -IsAudited $true

.EXAMPLE
    .\Add-DataverseChoiceField.ps1 -TableName "account" -ChoiceDisplayName "Priority Level" -ChoiceSchemaName "new_PriorityLevel" -ChoiceValues "Low,Medium,High" -IsGlobal $false -SolutionName "MyCustomSolution"

.NOTES
    Requires the Microsoft.PowerApps.Administration.PowerShell and Microsoft.Xrm.Data.PowerShell modules.
    Run 'Install-Module -Name Microsoft.PowerApps.Administration.PowerShell' if needed.
    Run 'Install-Module -Name Microsoft.Xrm.Data.PowerShell' if needed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TableName,

    [Parameter(Mandatory = $true)]
    [string]$ChoiceDisplayName,

    [Parameter(Mandatory = $true)]
    [string]$ChoiceSchemaName,

    [Parameter(Mandatory = $false)]
    [string]$GlobalChoiceName,

    [Parameter(Mandatory = $true)]
    [string]$ChoiceValues,

    [Parameter(Mandatory = $false)]
    [string]$IsGlobal = "true",

    [Parameter(Mandatory = $false)]
    [string]$SolutionName,

    [Parameter(Mandatory = $false)]
    [string]$IsMandatory = "false",

    [Parameter(Mandatory = $false)]
    [string]$IsAudited = "false",

    [Parameter(Mandatory = $false)]
    [string]$IsMultiSelect = "false"
)

# Convert string parameters to boolean
function ConvertTo-Bool($val) {
    switch ($val.ToLower()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        '$true' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        '$false' { return $false }
        default { return $false }
    }
}

$IsMandatoryBool = ConvertTo-Bool $IsMandatory
$IsAuditedBool = ConvertTo-Bool $IsAudited
$IsMultiSelectBool = ConvertTo-Bool $IsMultiSelect
$IsGlobalBool = ConvertTo-Bool $IsGlobal
# Import common functions from DataverseCommon module
Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

function New-GlobalOptionSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Options,
        
        [Parameter(Mandatory = $false)]
        [string]$SolutionName
    )

    Write-Host "Creating global option set '$DisplayName'..." -ForegroundColor Yellow
    
    # Check if option set already exists using metadata service
    try {
        $request = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveOptionSetRequest
        $request.Name = $Name.ToLower()
        $request.RetrieveAsIfPublished = $true
        
        $response = $Connection.Execute($request)
        
        if ($null -ne $response) {
            Write-Host "Global option set '$Name' already exists. Skipping creation." -ForegroundColor Yellow
            return $Name
        }
    }
    catch {
        # If exception is thrown, the option set doesn't exist, so we continue with creation
        Write-Verbose "Option set doesn't exist. Will create a new one."
    }
    
    try {
        # Create the global option set metadata
        $optionSetMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.OptionSetMetadata
        $optionSetMetadata.Name = $Name
        $optionSetMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($DisplayName, 1033)
        $optionSetMetadata.IsGlobal = $true
        $optionSetMetadata.OptionSetType = [Microsoft.Xrm.Sdk.Metadata.OptionSetType]::Picklist
        
        # Create options array
        $optionsArray = New-Object Microsoft.Xrm.Sdk.Metadata.OptionMetadata[] $Options.Length
        
        for ($i = 0; $i -lt $Options.Length; $i++) {
            $option = New-Object Microsoft.Xrm.Sdk.Metadata.OptionMetadata
            $option.Value = $i * 10 + 10000000  # Starting from 10000000 with increments of 10
            $option.Label = New-Object Microsoft.Xrm.Sdk.Label($Options[$i], 1033)
            $optionsArray[$i] = $option
        }
        
        # Use CreateOptionSetRequest with properly formatted options
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateOptionSetRequest
        $createRequest.OptionSet = $optionSetMetadata
        $createRequest.OptionSet.Options.AddRange($optionsArray)
        
        # If solution is specified, add to solution
        if (-not [string]::IsNullOrEmpty($SolutionName)) {
            $createRequest.SolutionUniqueName = $SolutionName
        }
        
        # Execute the request and capture output to prevent it from being returned
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Global option set '$DisplayName' created successfully." -ForegroundColor Green
        return $Name
    }
    catch {
        Write-Error "Failed to create global option set: $_"
        throw
    }
}

function Add-ChoiceFieldToTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$FieldSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$FieldDisplayName,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsGlobal = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$GlobalOptionSetName,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ChoiceOptions,
        
        [Parameter(Mandatory = $false)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsMandatory = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsMultiSelect = $false
    )

    Write-Host "Adding choice field '$FieldDisplayName' to table '$TableName'..." -ForegroundColor Yellow
    
    # Check if the field already exists
    if (Test-AttributeExists -TableName $TableName -AttributeLogicalName $FieldSchemaName.ToLower()) {
        Write-Host "Field '$FieldSchemaName' already exists in table '$TableName'. Skipping creation." -ForegroundColor Yellow
        return
    }
    
    if ($IsGlobal -and [string]::IsNullOrWhiteSpace($GlobalOptionSetName)) {
        throw "GlobalOptionSetName is required when IsGlobal is `$true."
    }
    if (-not $IsGlobal -and (-not $ChoiceOptions -or $ChoiceOptions.Length -eq 0)) {
        throw "ChoiceOptions is required when IsGlobal is `$false."
    }
    
    try {
        # Create the picklist attribute metadata
        $attributeMetadata = $null
        
        if ($IsMultiSelect) {
            $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.MultiSelectPicklistAttributeMetadata
            # Set properties specific to MultiSelectPicklistAttributeMetadata
            $attributeMetadata.ColumnNumber = 100  # Default column number for multiselect
            $attributeMetadata.Format = [Microsoft.Xrm.Sdk.Metadata.OptionSetFormat]::Text
        } else {
            $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.PicklistAttributeMetadata
        }
        
        $attributeMetadata.SchemaName = $FieldSchemaName
        $attributeMetadata.LogicalName = $FieldSchemaName.ToLower()
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($FieldDisplayName, 1033)
        
        # Set the required level - using enum value instead of constructor
        if ($IsMandatory) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Set the option set reference
        $attributeMetadata.OptionSet = New-Object Microsoft.Xrm.Sdk.Metadata.OptionSetMetadata
        if ($IsGlobal) {
            $attributeMetadata.OptionSet.IsGlobal = $true
            $attributeMetadata.OptionSet.Name = $GlobalOptionSetName
        }
        else {
            # Local option set: options are defined inline on the attribute, not referenced by name
            $attributeMetadata.OptionSet.IsGlobal = $false
            $attributeMetadata.OptionSet.OptionSetType = [Microsoft.Xrm.Sdk.Metadata.OptionSetType]::Picklist

            $localOptionsArray = New-Object Microsoft.Xrm.Sdk.Metadata.OptionMetadata[] $ChoiceOptions.Length
            for ($i = 0; $i -lt $ChoiceOptions.Length; $i++) {
                $option = New-Object Microsoft.Xrm.Sdk.Metadata.OptionMetadata
                $option.Value = $i * 10 + 10000000  # Starting from 10000000 with increments of 10
                $option.Label = New-Object Microsoft.Xrm.Sdk.Label($ChoiceOptions[$i], 1033)
                $localOptionsArray[$i] = $option
            }
            $attributeMetadata.OptionSet.Options.AddRange($localOptionsArray)
        }
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # If solution is specified, add to solution
        if (-not [string]::IsNullOrEmpty($SolutionName)) {
            $createRequest.SolutionUniqueName = $SolutionName
        }
        
        # Execute the request and capture output to prevent it from being returned
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Choice field '$FieldDisplayName' added to table '$TableName' successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to add choice field to table: $_"
        throw
    }
}

# Main script execution
try {
    # Import required modules
    Import-RequiredModules
    
    # Connect to Dataverse
    $connection = Connect-ToDataverse
    
    # Verify if solution exists
    if ($SolutionName -and -not (Confirm-SolutionExists -SolutionName $SolutionName)) {
        Write-Error "Specified solution does not exist. Exiting."
        exit 1
    }
    
    # Split the choice values into an array
    $choiceValueArray = $ChoiceValues -split ',' | ForEach-Object { $_.Trim() }
    
    if ($IsGlobalBool) {
        if ([string]::IsNullOrWhiteSpace($GlobalChoiceName)) {
            Write-Error "GlobalChoiceName is required when IsGlobal is true. Exiting."
            exit 1
        }

        # Create the global option set
        $globalOptionSetName = New-GlobalOptionSet -Name $GlobalChoiceName -DisplayName $ChoiceDisplayName -Options $choiceValueArray -SolutionName $SolutionName
    
        # Add the field to the table, referencing the global option set
        Add-ChoiceFieldToTable -TableName $TableName -FieldSchemaName $ChoiceSchemaName -FieldDisplayName $ChoiceDisplayName -IsGlobal $true -GlobalOptionSetName $globalOptionSetName -SolutionName $SolutionName -IsMandatory $IsMandatoryBool -IsAudited $IsAuditedBool -IsMultiSelect $IsMultiSelectBool
    }
    else {
        # Add the field to the table with a local, field-scoped option set
        Add-ChoiceFieldToTable -TableName $TableName -FieldSchemaName $ChoiceSchemaName -FieldDisplayName $ChoiceDisplayName -IsGlobal $false -ChoiceOptions $choiceValueArray -SolutionName $SolutionName -IsMandatory $IsMandatoryBool -IsAudited $IsAuditedBool -IsMultiSelect $IsMultiSelectBool
    }
    
    Write-Host "Operation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
