#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Exports the schema of a Dataverse table to a CSV file.

.DESCRIPTION
    This script reads the schema/metadata of a specified Dataverse table and exports 
    field information (display name, logical name, schema name, and data type) to a CSV file.

.PARAMETER TableName
    The logical name of the table to export schema for.

.PARAMETER OutputPath
    The path where the CSV file will be saved. If not specified, will save to current directory 
    with filename format: {TableName}_Schema_{timestamp}.csv

.PARAMETER IncludeSystemFields
    Optional. If specified, includes system fields (like createdon, modifiedby, etc.) in the export.
    Default is $false to only show custom fields.

.PARAMETER IncludeFieldDetails
    Optional. If specified, includes additional field details like required level, maximum length, etc.
    Default is $false for basic export.

.EXAMPLE
    .\Export-DataverseTableSchema.ps1 -TableName "account" -OutputPath "C:\Export\account_schema.csv"

.EXAMPLE
    .\Export-DataverseTableSchema.ps1 -TableName "ppcc_p2ecase" -IncludeSystemFields $true

.EXAMPLE
    .\Export-DataverseTableSchema.ps1 -TableName "contact" -IncludeFieldDetails $true -OutputPath "C:\Schemas\contact_detailed.csv"

.NOTES
    Requires the Microsoft.PowerApps.Administration.PowerShell and Microsoft.Xrm.Data.PowerShell modules.
    Run 'Install-Module -Name Microsoft.PowerApps.Administration.PowerShell' if needed.
    Run 'Install-Module -Name Microsoft.Xrm.Data.PowerShell' if needed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TableName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeSystemFields,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeFieldDetails
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

function ConvertTo-SchemaData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Sdk.Metadata.AttributeMetadata[]]$Attributes,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeSystemFields = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeFieldDetails = $false
    )

    Write-Host "Converting metadata to CSV data..." -ForegroundColor Yellow
    
    $schemaData = @()
    
    foreach ($attribute in $Attributes) {
        # Skip system fields unless explicitly requested
        if (-not $IncludeSystemFields) {
            # List of common system fields to exclude
            $systemFields = @(
                'createdon', 'createdby', 'modifiedon', 'modifiedby', 'ownerid', 'owningbusinessunit',
                'owningteam', 'owninguser', 'statecode', 'statuscode', 'timezoneruleversionnumber',
                'utcconversiontimezonecode', 'versionnumber', 'importsequencenumber', 'overriddencreatedon',
                'entityimage', 'entityimageid', 'entityimageurl', 'entityimagetimestamp'
            )
            
            if ($systemFields -contains $attribute.LogicalName.ToLower()) {
                continue
            }
        }
        
        # Get display name
        $displayName = if ($attribute.DisplayName -and $attribute.DisplayName.UserLocalizedLabel) {
            $attribute.DisplayName.UserLocalizedLabel.Label
        } else {
            $attribute.LogicalName
        }
        
        # Get description
        $description = if ($attribute.Description -and $attribute.Description.UserLocalizedLabel) {
            $attribute.Description.UserLocalizedLabel.Label
        } else {
            ""
        }
        
        # Create base data object
        $fieldData = [PSCustomObject]@{
            DisplayName = $displayName
            LogicalName = $attribute.LogicalName
            SchemaName = $attribute.SchemaName
            DataType = $attribute.AttributeType.ToString()
            IsCustomField = $attribute.IsCustomAttribute
            Description = $description
        }
        
        # Add detailed information if requested
        if ($IncludeFieldDetails) {
            $fieldData | Add-Member -NotePropertyName "IsRequired" -NotePropertyValue ($attribute.RequiredLevel -eq [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired)
            $fieldData | Add-Member -NotePropertyName "IsAudited" -NotePropertyValue $attribute.IsAuditEnabled.Value
            $fieldData | Add-Member -NotePropertyName "IsPrimaryId" -NotePropertyValue $attribute.IsPrimaryId.Value
            $fieldData | Add-Member -NotePropertyName "IsPrimaryName" -NotePropertyValue $attribute.IsPrimaryName.Value
            $fieldData | Add-Member -NotePropertyName "IsValidForRead" -NotePropertyValue $attribute.IsValidForRead.Value
            $fieldData | Add-Member -NotePropertyName "IsValidForCreate" -NotePropertyValue $attribute.IsValidForCreate.Value
            $fieldData | Add-Member -NotePropertyName "IsValidForUpdate" -NotePropertyValue $attribute.IsValidForUpdate.Value
            
            # Add type-specific details
            switch ($attribute.AttributeType) {
                "String" {
                    $stringAttr = [Microsoft.Xrm.Sdk.Metadata.StringAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "MaxLength" -NotePropertyValue $stringAttr.MaxLength
                    $fieldData | Add-Member -NotePropertyName "Format" -NotePropertyValue $stringAttr.Format.ToString()
                }
                "Memo" {
                    $memoAttr = [Microsoft.Xrm.Sdk.Metadata.MemoAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "MaxLength" -NotePropertyValue $memoAttr.MaxLength
                }
                "Integer" {
                    $intAttr = [Microsoft.Xrm.Sdk.Metadata.IntegerAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "MinValue" -NotePropertyValue $intAttr.MinValue
                    $fieldData | Add-Member -NotePropertyName "MaxValue" -NotePropertyValue $intAttr.MaxValue
                }
                "Decimal" {
                    $decimalAttr = [Microsoft.Xrm.Sdk.Metadata.DecimalAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "MinValue" -NotePropertyValue $decimalAttr.MinValue
                    $fieldData | Add-Member -NotePropertyName "MaxValue" -NotePropertyValue $decimalAttr.MaxValue
                    $fieldData | Add-Member -NotePropertyName "Precision" -NotePropertyValue $decimalAttr.Precision
                }
                "Money" {
                    $moneyAttr = [Microsoft.Xrm.Sdk.Metadata.MoneyAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "MinValue" -NotePropertyValue $moneyAttr.MinValue
                    $fieldData | Add-Member -NotePropertyName "MaxValue" -NotePropertyValue $moneyAttr.MaxValue
                    $fieldData | Add-Member -NotePropertyName "Precision" -NotePropertyValue $moneyAttr.Precision
                }
                "Double" {
                    $doubleAttr = [Microsoft.Xrm.Sdk.Metadata.DoubleAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "MinValue" -NotePropertyValue $doubleAttr.MinValue
                    $fieldData | Add-Member -NotePropertyName "MaxValue" -NotePropertyValue $doubleAttr.MaxValue
                    $fieldData | Add-Member -NotePropertyName "Precision" -NotePropertyValue $doubleAttr.Precision
                }
                "DateTime" {
                    $dateAttr = [Microsoft.Xrm.Sdk.Metadata.DateTimeAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "Format" -NotePropertyValue $dateAttr.Format.ToString()
                    $fieldData | Add-Member -NotePropertyName "DateTimeBehavior" -NotePropertyValue $dateAttr.DateTimeBehavior.Value.ToString()
                }
                "Lookup" {
                    $lookupAttr = [Microsoft.Xrm.Sdk.Metadata.LookupAttributeMetadata]$attribute
                    $targets = if ($lookupAttr.Targets -and $lookupAttr.Targets.Count -gt 0) {
                        $lookupAttr.Targets -join "; "
                    } else {
                        ""
                    }
                    $fieldData | Add-Member -NotePropertyName "TargetEntities" -NotePropertyValue $targets
                }
                "Picklist" {
                    $picklistAttr = [Microsoft.Xrm.Sdk.Metadata.PicklistAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "OptionSetName" -NotePropertyValue $picklistAttr.OptionSet.Name
                    $fieldData | Add-Member -NotePropertyName "IsGlobalOptionSet" -NotePropertyValue $picklistAttr.OptionSet.IsGlobal
                }
                "MultiSelectPicklist" {
                    $multiPicklistAttr = [Microsoft.Xrm.Sdk.Metadata.MultiSelectPicklistAttributeMetadata]$attribute
                    $fieldData | Add-Member -NotePropertyName "OptionSetName" -NotePropertyValue $multiPicklistAttr.OptionSet.Name
                    $fieldData | Add-Member -NotePropertyName "IsGlobalOptionSet" -NotePropertyValue $multiPicklistAttr.OptionSet.IsGlobal
                }
            }
        }
        
        $schemaData += $fieldData
    }
    
    Write-Host "Converted $(($schemaData | Measure-Object).Count) fields to CSV data." -ForegroundColor Green
    return $schemaData
}

function Export-SchemaToCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$SchemaData,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TableName
    )

    Write-Host "Exporting schema data to CSV file '$FilePath'..." -ForegroundColor Yellow
    
    try {
        # Ensure the directory exists
        $directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Write-Host "Created directory: $directory" -ForegroundColor Green
        }
        
        # Export to CSV
        $SchemaData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host "Schema exported successfully to: $FilePath" -ForegroundColor Green
        Write-Host "Total fields exported: $(($SchemaData | Measure-Object).Count)" -ForegroundColor Green
        
        # Display file info
        $fileInfo = Get-Item -Path $FilePath
        Write-Host "File size: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Green
        Write-Host "Created: $($fileInfo.CreationTime)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to export schema to CSV: $_"
        throw
    }
}

function Show-Summary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$SchemaData,
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-Host "`n=== Schema Export Summary ===" -ForegroundColor Cyan
    Write-Host "Table: $TableName" -ForegroundColor White
    Write-Host "Total fields exported: $(($SchemaData | Measure-Object).Count)" -ForegroundColor White
    Write-Host "Output file: $FilePath" -ForegroundColor White
    
    # Group by data type
    $typeGroups = $SchemaData | Group-Object -Property DataType | Sort-Object Name
    
    Write-Host "`nFields by Data Type:" -ForegroundColor Yellow
    foreach ($group in $typeGroups) {
        Write-Host " - $($group.Name): $($group.Count)" -ForegroundColor White
    }
    
    # Show custom vs system fields
    $customFields = $SchemaData | Where-Object { $_.IsCustomField -eq $true }
    $systemFields = $SchemaData | Where-Object { $_.IsCustomField -eq $false }
    
    Write-Host "`nField Categories:" -ForegroundColor Yellow
    Write-Host " - Custom fields: $(($customFields | Measure-Object).Count)" -ForegroundColor Green
    Write-Host " - System fields: $(($systemFields | Measure-Object).Count)" -ForegroundColor White
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
        $OutputPath = Join-Path -Path (Get-Location) -ChildPath "$($TableName)_Schema_$timestamp.csv"
    }
    
    # Get table metadata
    $entityMetadata = Get-TableMetadata -Connection $connection -TableLogicalName $TableName
    
    # Convert to schema data
    $schemaData = ConvertTo-SchemaData -Attributes $entityMetadata.Attributes -IncludeSystemFields $($IncludeSystemFields.IsPresent) -IncludeFieldDetails $($IncludeFieldDetails.IsPresent)
    
    # Export to CSV
    Export-SchemaToCsv -SchemaData $schemaData -FilePath $OutputPath -TableName $TableName
    
    # Show summary
    Show-Summary -SchemaData $schemaData -TableName $TableName -FilePath $OutputPath
    
    Write-Host "`nOperation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
