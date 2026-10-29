#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Creates a new table in Dataverse.

.DESCRIPTION
    This script creates a new table (entity) in a specified Dataverse environment and adds it to a specified solution.

.PARAMETER TableDisplayName
    The display name of the table (what users will see in the UI).

.PARAMETER TableSchemaName
    The schema name of the table (will be prefixed with customization prefix in Dataverse).

.PARAMETER TablePluralName
    The plural name of the table (used when displaying multiple records). If not specified, 's' will be appended to the display name.

.PARAMETER SolutionName
    The unique name of the solution to add the table to.

.PARAMETER Description
    Optional. A description for the table.

.PARAMETER OwnershipType
    Optional. The ownership type for the table. Possible values: 'Organization', 'User'. Default is 'Organization'.

.PARAMETER HasActivities
    Optional. Specifies whether the table supports activities. Default is $false.

.PARAMETER HasNotes
    Optional. Specifies whether the table supports notes. Default is $true.

.PARAMETER IsAuditEnabled
    Optional. Specifies whether auditing is enabled for the table. Default is $false.

.PARAMETER IsActivity
    Optional. Specifies whether the table is an activity entity type. Default is $false.
    Note: A table cannot be both an activity entity type and support activities.

.PARAMETER PrimaryFieldName
    Optional. The name of the primary field (schema name). Default is "Name".
    This will be used as the primary attribute for the table.

.PARAMETER PrimaryFieldDisplayName
    Optional. The display name of the primary field. Default is "Name".
    This will be shown in the UI for the primary attribute.

.PARAMETER PrimaryFieldMaxLength
    Optional. The maximum length of the primary field. Default is 100.

.EXAMPLE
    .\Add-DataverseTable.ps1 -TableDisplayName "Customer Request" -TableSchemaName "new_CustomerRequest" -TablePluralName "Customer Requests" -SolutionName "CustomerManagement" -Description "Table for tracking customer requests" -OwnershipType "User" -HasActivities $true -HasNotes $true -IsAuditEnabled $true

.EXAMPLE
    .\Add-DataverseTable.ps1 -TableDisplayName "Product Catalog" -TableSchemaName "new_ProductCatalog" -SolutionName "InventoryManagement"

.EXAMPLE
    .\Add-DataverseTable.ps1 -TableDisplayName "Phone Call" -TableSchemaName "CustomPhoneCall" -SolutionName "ActivityManagement" -IsActivity $true -PrimaryFieldName "Subject" -PrimaryFieldDisplayName "Phone Call Subject" -PrimaryFieldMaxLength 150

.NOTES
    Requires the Microsoft.PowerApps.Administration.PowerShell and Microsoft.Xrm.Data.PowerShell modules.
    Run 'Install-Module -Name Microsoft.PowerApps.Administration.PowerShell' if needed.
    Run 'Install-Module -Name Microsoft.Xrm.Data.PowerShell' if needed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TableDisplayName,

    [Parameter(Mandatory = $true)]
    [string]$TableSchemaName,
    
    [Parameter(Mandatory = $false)]
    [string]$TablePluralName,

    [Parameter(Mandatory = $true)]
    [string]$SolutionName,

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Organization", "User")]
    [string]$OwnershipType = "Organization",

    [Parameter(Mandatory = $false)]
    [bool]$HasActivities = $false,

    [Parameter(Mandatory = $false)]
    [bool]$HasNotes = $true,

    [Parameter(Mandatory = $false)]
    [bool]$IsAuditEnabled = $true,

    [Parameter(Mandatory = $false)]
    [bool]$IsActivity = $false,

    [Parameter(Mandatory = $false)]
    [string]$PrimaryFieldName = "Name",

    [Parameter(Mandatory = $false)]
    [string]$PrimaryFieldDisplayName = "Name",

    [Parameter(Mandatory = $false)]
    [int]$PrimaryFieldMaxLength = 250
)

# Import common functions from DataverseCommon module
Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

function New-DataverseTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        
        [Parameter(Mandatory = $true)]
        [string]$TableSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$TableDisplayName,
        
        [Parameter(Mandatory = $false)]
        [string]$TablePluralName,
        
        [Parameter(Mandatory = $true)]
        [string]$CustomizationPrefix,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Organization", "User")]
        [string]$OwnershipType = "User",
        
        [Parameter(Mandatory = $false)]
        [bool]$HasActivities = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$HasNotes = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAuditEnabled = $false,

        [Parameter(Mandatory = $false)]
        [bool]$IsActivity = $false,

        [Parameter(Mandatory = $false)]
        [string]$PrimaryFieldName = "Name",

        [Parameter(Mandatory = $false)]
        [string]$PrimaryFieldDisplayName = "Name",

        [Parameter(Mandatory = $false)]
        [int]$PrimaryFieldMaxLength = 100
    )

    # Create the logical name with prefix
    $tableLogicalName = $TableSchemaName.ToLower()
    
    # Check if the table already exists
    if (Test-TableExists -Connection $Connection -TableLogicalName $tableLogicalName) {
        Write-Host "Table '$tableLogicalName' already exists. Skipping creation." -ForegroundColor Yellow
        return $tableLogicalName
    }
    
    Write-Host "Creating new table '$TableDisplayName' ($tableLogicalName)..." -ForegroundColor Yellow
    
    try {
        # Create the entity metadata
        $entityMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.EntityMetadata
        $entityMetadata.SchemaName = $TableSchemaName
        $entityMetadata.LogicalName = $tableLogicalName
        $entityMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($TableDisplayName, 1033)
        
        # Set the plural name
        if ([string]::IsNullOrEmpty($TablePluralName)) {
            # Default to adding 's' to the display name if no plural name specified
            $TablePluralName = "$TableDisplayName`s"
        }
        $entityMetadata.DisplayCollectionName = New-Object Microsoft.Xrm.Sdk.Label($TablePluralName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $entityMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set ownership type
        if ($OwnershipType -eq "User") {
            $entityMetadata.OwnershipType = [Microsoft.Xrm.Sdk.Metadata.OwnershipTypes]::UserOwned
        } else {
            $entityMetadata.OwnershipType = [Microsoft.Xrm.Sdk.Metadata.OwnershipTypes]::OrganizationOwned
        }
        
        # Set additional properties
        $entityMetadata.IsActivity = New-Object System.Nullable[bool]($IsActivity)
        
        # If it's an activity entity, it can't support activities
        if ($IsActivity) {
            $entityMetadata.HasActivities = New-Object System.Nullable[bool]($false)
        } else {
            $entityMetadata.HasActivities = New-Object System.Nullable[bool]($HasActivities)
        }
        
        $entityMetadata.HasNotes = New-Object System.Nullable[bool]($HasNotes)
        $entityMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAuditEnabled)
        $entityMetadata.IsAvailableOffline = New-Object System.Nullable[bool]($true)
        $entityMetadata.IsMailMergeEnabled = New-Object System.Nullable[bool]($false)
        $entityMetadata.IsVisibleInMobile = New-Object System.Nullable[bool]($true)
        $entityMetadata.IsVisibleInMobileClient = New-Object System.Nullable[bool]($true)
        
        
        # Create primary attribute (required for table creation)
        $primaryAttribute = New-Object Microsoft.Xrm.Sdk.Metadata.StringAttributeMetadata
        $primaryAttribute.SchemaName = "$($CustomizationPrefix)_$($PrimaryFieldName)"
        $primaryAttribute.LogicalName = "$($CustomizationPrefix)_$($PrimaryFieldName.ToLower())"
        $primaryAttribute.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($PrimaryFieldDisplayName, 1033)
        $primaryAttribute.RequiredLevel = New-Object Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel
        $primaryAttribute.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::Required
        $primaryAttribute.MaxLength = $PrimaryFieldMaxLength
        
        # Create the request to create the entity
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateEntityRequest
        $createRequest.Entity = $entityMetadata
        $createRequest.PrimaryAttribute = $primaryAttribute
        $createRequest.HasNotes = $HasNotes
        $createRequest.HasActivities = $HasActivities
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Table '$TableDisplayName' ($tableLogicalName) created successfully." -ForegroundColor Green
        return $tableLogicalName
    }
    catch {
        Write-Error "Failed to create table: $_"
        throw
    }
}

# Main script execution
try {
    # Import required modules from common module
    Import-RequiredModules
    
    # Connect to Dataverse
    $connection = Connect-ToDataverse
    
    # Verify if solution exists
    if (-not (Confirm-SolutionExists -Connection $connection -SolutionName $SolutionName)) {
        Write-Error "Specified solution does not exist. Exiting."
        exit 1
    }
    
    # Get customization prefix for the solution
    $customizationPrefix = Get-CustomizationPrefix -Connection $connection -SolutionName $SolutionName
    
    if (-not $customizationPrefix) {
        Write-Error "Failed to retrieve customization prefix for solution '$SolutionName'. Exiting."
        exit 1
    }
    
    # Create the table
    $tableLogicalName = New-DataverseTable -Connection $connection -TableSchemaName $TableSchemaName -TableDisplayName $TableDisplayName -TablePluralName $TablePluralName -CustomizationPrefix $customizationPrefix -SolutionName $SolutionName -Description $Description -OwnershipType $OwnershipType -HasActivities $HasActivities -HasNotes $HasNotes -IsAuditEnabled $IsAuditEnabled -IsActivity $IsActivity -PrimaryFieldName $PrimaryFieldName -PrimaryFieldDisplayName $PrimaryFieldDisplayName -PrimaryFieldMaxLength $PrimaryFieldMaxLength
    
    Write-Host "Table creation process completed successfully!" -ForegroundColor Green
    Write-Host "Table Logical Name: $tableLogicalName" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}

