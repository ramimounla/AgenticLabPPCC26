#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Adds an attribute (field) to a table in Dataverse.

.DESCRIPTION
    This script adds a new attribute (field) of various types (text, date, lookup, or boolean) to an existing table in Dataverse.

.PARAMETER TableName
    The logical name of the table to add the attribute to.

.PARAMETER AttributeDisplayName
    The display name of the attribute (what users will see in the UI).

.PARAMETER AttributeSchemaName
    The schema name of the attribute (will be prefixed with customization prefix in Dataverse).

.PARAMETER AttributeType
    The type of attribute to create. Possible values: 'Text', 'Date', 'Lookup', 'Boolean', 'Decimal', 'Integer', 'Money'.

.PARAMETER SolutionName
    The unique name of the solution to add the attribute to.

.PARAMETER MaxLength
    Optional. For Text attributes, the maximum length of the text field. Default is 100.

.PARAMETER Format
    Optional. For Date attributes, the format of the date. Possible values: 'DateOnly', 'DateAndTime'. Default is 'DateOnly'.

.PARAMETER TargetTable
    Optional. For Lookup attributes, the logical name of the table the lookup points to.

.PARAMETER IsRequired
    Optional. Specifies whether the attribute is required. Default is $false.

.PARAMETER IsAudited
    Optional. Specifies whether the attribute is audited. Default is $false.

.PARAMETER Description
    Optional. A description for the attribute.

.PARAMETER Precision
    Optional. For Decimal and Money attributes, the precision (number of decimal places). Default is 2.

.PARAMETER MinValue
    Optional. For Decimal, Integer, and Money attributes, the minimum allowed value.

.PARAMETER MaxValue
    Optional. For Decimal, Integer, and Money attributes, the maximum allowed value.

.EXAMPLE
    .\Add-DataverseAttribute.ps1 -TableName "account" -AttributeDisplayName "Customer Number" -AttributeSchemaName "CustomerNumber" -AttributeType "Text" -SolutionName "CustomerManagement" -MaxLength 20 -IsRequired $true

.EXAMPLE
    .\Add-DataverseAttribute.ps1 -TableName "contact" -AttributeDisplayName "Birth Date" -AttributeSchemaName "BirthDate" -AttributeType "Date" -SolutionName "ContactManagement" -Format "DateOnly"

.EXAMPLE
    .\Add-DataverseAttribute.ps1 -TableName "incident" -AttributeDisplayName "Primary Contact" -AttributeSchemaName "PrimaryContact" -AttributeType "Lookup" -SolutionName "ServiceManagement" -TargetTable "contact" -IsRequired $true
    .\Add-DataverseAttribute.ps1 -TableName "ppcc_p2ecase" -AttributeDisplayName "Client Benefits" -AttributeSchemaName "ppcc_clientbenefits" -AttributeType "Lookup" -SolutionName "P2E" -TargetTable "ppcc_clientbenefit" -IsRequired $false

.EXAMPLE
    .\Add-DataverseAttribute.ps1 -TableName "account" -AttributeDisplayName "Is Active" -AttributeSchemaName "IsActive" -AttributeType "Boolean" -SolutionName "AccountManagement"

.EXAMPLE
    .\Add-DataverseAttribute.ps1 -TableName "product" -AttributeDisplayName "Unit Price" -AttributeSchemaName "UnitPrice" -AttributeType "Money" -SolutionName "ProductManagement" -Precision 2 -MinValue 0 -MaxValue 1000000

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
    [string]$AttributeDisplayName,

    [Parameter(Mandatory = $true)]
    [string]$AttributeSchemaName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Text", "Date", "Lookup", "Boolean", "Decimal", "Integer", "Money")]
    [string]$AttributeType,

    [Parameter(Mandatory = $true)]
    [string]$SolutionName,

    [Parameter(Mandatory = $false)]
    [int]$MaxLength = 250,

    [Parameter(Mandatory = $false)]
    [ValidateSet("DateOnly", "DateAndTime")]
    [string]$Format = "DateOnly",

    [Parameter(Mandatory = $false)]
    [string]$TargetTable,

    [Parameter(Mandatory = $false)]
    [string]$IsRequired = "false",

    [Parameter(Mandatory = $false)]
    [string]$IsAudited = "false",

    [Parameter(Mandatory = $false)]
    [string]$Description = "",

    [Parameter(Mandatory = $false)]
    [int]$Precision = 2,

    [Parameter(Mandatory = $false)]
    [double]$MinValue,

    [Parameter(Mandatory = $false)]
    [double]$MaxValue
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

$IsRequiredBool = ConvertTo-Bool $IsRequired
$IsAuditedBool = ConvertTo-Bool $IsAudited

# Import common functions from DataverseCommon module
Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

# These functions are now imported from DataverseCommon.psm1:
# - Get-CustomizationPrefix
# - Test-AttributeExists

function Add-TextAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxLength = 100,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    Write-Host "Creating text attribute '$AttributeDisplayName' in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        # Create the attribute metadata
        $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.StringAttributeMetadata
        $attributeMetadata.SchemaName = $AttributeSchemaName
        $attributeMetadata.LogicalName = $AttributeLogicalName
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $attributeMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $attributeMetadata.MaxLength = $MaxLength
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Text attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create text attribute: $_"
        throw
    }
}

function Add-DateAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("DateOnly", "DateAndTime")]
        [string]$Format = "DateOnly",
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    Write-Host "Creating date attribute '$AttributeDisplayName' in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        # Create the attribute metadata
        $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.DateTimeAttributeMetadata
        $attributeMetadata.SchemaName = $AttributeSchemaName
        $attributeMetadata.LogicalName = $AttributeLogicalName
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $attributeMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        # Set the date time format
        if ($Format -eq "DateOnly") {
            $attributeMetadata.Format = [Microsoft.Xrm.Sdk.Metadata.DateTimeFormat]::DateOnly
        } else {
            $attributeMetadata.Format = [Microsoft.Xrm.Sdk.Metadata.DateTimeFormat]::DateAndTime
        }
        
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Date attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create date attribute: $_"
        throw
    }
}

function Add-LookupAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetTable,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    Write-Host "Creating lookup attribute '$AttributeDisplayName' in table '$TableName' targeting '$TargetTable'..." -ForegroundColor Yellow
    
    try {
        # Use a simple relationship name based on the table names
        $relationshipSchemaName = "${TableName}_${TargetTable}"
        
        # Create the lookup field
        $lookupField = New-Object Microsoft.Xrm.Sdk.Metadata.LookupAttributeMetadata
        $lookupField.SchemaName = $AttributeSchemaName
        $lookupField.LogicalName = $AttributeLogicalName
        $lookupField.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $lookupField.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $lookupField.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $lookupField.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $lookupField.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Create relationship metadata
        $relationshipMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.OneToManyRelationshipMetadata
        $relationshipMetadata.SchemaName = $relationshipSchemaName
        $relationshipMetadata.ReferencedEntity = $TargetTable
        $relationshipMetadata.ReferencingEntity = $TableName
        
        # Create the request to create the relationship with the lookup field
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateOneToManyRequest
        $createRequest.OneToManyRelationship = $relationshipMetadata
        $createRequest.Lookup = $lookupField
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request to create both the relationship and lookup field in one operation
        Write-Host "Creating lookup attribute and relationship in '$TableName' referencing '$TargetTable'..." -ForegroundColor Yellow
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Lookup attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create lookup attribute: $_"
        Write-Error "Exception details: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
        }
        throw
    }
}

function Add-BooleanAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        
        [Parameter(Mandatory = $false)]
        [string]$TrueLabel = "Yes",
        
        [Parameter(Mandatory = $false)]
        [string]$FalseLabel = "No"
    )

    Write-Host "Creating boolean attribute '$AttributeDisplayName' in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        # Create the attribute metadata
        $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.BooleanAttributeMetadata
        $attributeMetadata.SchemaName = $AttributeSchemaName
        $attributeMetadata.LogicalName = $AttributeLogicalName
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $attributeMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Set the option labels
        $attributeMetadata.OptionSet = New-Object Microsoft.Xrm.Sdk.Metadata.BooleanOptionSetMetadata
        $attributeMetadata.OptionSet.TrueOption = New-Object Microsoft.Xrm.Sdk.Metadata.OptionMetadata
        $attributeMetadata.OptionSet.TrueOption.Label = New-Object Microsoft.Xrm.Sdk.Label($TrueLabel, 1033)
        $attributeMetadata.OptionSet.TrueOption.Value = 1
        
        $attributeMetadata.OptionSet.FalseOption = New-Object Microsoft.Xrm.Sdk.Metadata.OptionMetadata
        $attributeMetadata.OptionSet.FalseOption.Label = New-Object Microsoft.Xrm.Sdk.Label($FalseLabel, 1033)
        $attributeMetadata.OptionSet.FalseOption.Value = 0
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Boolean attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create boolean attribute: $_"
        throw
    }
}

function Add-DecimalAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [int]$Precision = 2,
        
        [Parameter(Mandatory = $false)]
        [Nullable[double]]$MinValue,
        
        [Parameter(Mandatory = $false)]
        [Nullable[double]]$MaxValue,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    Write-Host "Creating decimal attribute '$AttributeDisplayName' in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        # Create the attribute metadata
        $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.DecimalAttributeMetadata
        $attributeMetadata.SchemaName = $AttributeSchemaName
        $attributeMetadata.LogicalName = $AttributeLogicalName
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $attributeMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $attributeMetadata.Precision = $Precision
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Set min and max values if specified
        if ($PSBoundParameters.ContainsKey('MinValue')) {
            $attributeMetadata.MinValue = New-Object System.Nullable[decimal]($MinValue)
        }
        
        if ($PSBoundParameters.ContainsKey('MaxValue')) {
            $attributeMetadata.MaxValue = New-Object System.Nullable[decimal]($MaxValue)
        }
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Decimal attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create decimal attribute: $_"
        throw
    }
}

function Add-IntegerAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [Nullable[int]]$MinValue,
        
        [Parameter(Mandatory = $false)]
        [Nullable[int]]$MaxValue,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    Write-Host "Creating integer attribute '$AttributeDisplayName' in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        # Create the attribute metadata
        $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.IntegerAttributeMetadata
        $attributeMetadata.SchemaName = $AttributeSchemaName
        $attributeMetadata.LogicalName = $AttributeLogicalName
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $attributeMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Set min and max values if specified
        if ($PSBoundParameters.ContainsKey('MinValue')) {
            $attributeMetadata.MinValue = New-Object System.Nullable[int]($MinValue)
        }
        
        if ($PSBoundParameters.ContainsKey('MaxValue')) {
            $attributeMetadata.MaxValue = New-Object System.Nullable[int]($MaxValue)
        }
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Integer attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create integer attribute: $_"
        throw
    }
}

function Add-MoneyAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeSchemaName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeDisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,
        
        [Parameter(Mandatory = $false)]
        [int]$Precision = 2,
        
        [Parameter(Mandatory = $false)]
        [Nullable[double]]$MinValue,
        
        [Parameter(Mandatory = $false)]
        [Nullable[double]]$MaxValue,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsRequired = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsAudited = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    Write-Host "Creating money attribute '$AttributeDisplayName' in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        # Create the attribute metadata
        $attributeMetadata = New-Object Microsoft.Xrm.Sdk.Metadata.MoneyAttributeMetadata
        $attributeMetadata.SchemaName = $AttributeSchemaName
        $attributeMetadata.LogicalName = $AttributeLogicalName
        $attributeMetadata.DisplayName = New-Object Microsoft.Xrm.Sdk.Label($AttributeDisplayName, 1033)
        
        if (-not [string]::IsNullOrEmpty($Description)) {
            $attributeMetadata.Description = New-Object Microsoft.Xrm.Sdk.Label($Description, 1033)
        }
        
        # Set the required level
        if ($IsRequired) {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::ApplicationRequired
        } else {
            $attributeMetadata.RequiredLevel = [Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None
        }
        
        $attributeMetadata.Precision = $Precision
        $attributeMetadata.IsAuditEnabled = New-Object System.Nullable[bool]($IsAudited)
        
        # Set min and max values if specified
        if ($PSBoundParameters.ContainsKey('MinValue')) {
            $attributeMetadata.MinValue = New-Object System.Nullable[decimal]($MinValue)
        }
        
        if ($PSBoundParameters.ContainsKey('MaxValue')) {
            $attributeMetadata.MaxValue = New-Object System.Nullable[decimal]($MaxValue)
        }
        
        # Create the request to create the attribute
        $createRequest = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
        $createRequest.EntityName = $TableName
        $createRequest.Attribute = $attributeMetadata
        
        # Add to solution
        $createRequest.SolutionUniqueName = $SolutionName
        
        # Execute the request
        $null = $Connection.Execute($createRequest)
        
        Write-Host "Money attribute '$AttributeDisplayName' created successfully in table '$TableName'." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create money attribute: $_"
        throw
    }
}

# Main script execution
try {
    # Connect to Dataverse
    $connection = Get-DataverseConnection
    
    # Verify if solution exists
    if (-not (Confirm-SolutionExists -SolutionName $SolutionName)) {
        Write-Error "Specified solution does not exist. Exiting."
        exit 1
    }
    
    # Get customization prefix for the solution
    $customizationPrefix = Get-CustomizationPrefix -SolutionName $SolutionName
    
    if (-not $customizationPrefix) {
        Write-Error "Failed to retrieve customization prefix for solution '$SolutionName'. Exiting."
        exit 1
    }
    
    # Create the attribute logical name with prefix
    $attributeLogicalName = $AttributeSchemaName.ToLower()
    
    # Check if the attribute already exists
    if (Test-AttributeExists -TableName $TableName -AttributeLogicalName $attributeLogicalName) {
        Write-Host "Attribute '$attributeLogicalName' already exists in table '$TableName'. Skipping creation." -ForegroundColor Yellow
        exit 0
    }
    
    # Add the attribute based on the type
    switch ($AttributeType) {
        "Text" {
            Add-TextAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -SolutionName $SolutionName -MaxLength $MaxLength -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
        "Date" {
            Add-DateAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -SolutionName $SolutionName -Format $Format -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
        "Lookup" {
            if (-not $TargetTable) {
                Write-Error "TargetTable parameter is required for Lookup attributes. Exiting."
                exit 1
            }
            Add-LookupAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -TargetTable $TargetTable -SolutionName $SolutionName -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
        "Boolean" {
            Add-BooleanAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -SolutionName $SolutionName -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
        "Decimal" {
            Add-DecimalAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -SolutionName $SolutionName -Precision $Precision -MinValue $MinValue -MaxValue $MaxValue -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
        "Integer" {
            Add-IntegerAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -SolutionName $SolutionName -MinValue $MinValue -MaxValue $MaxValue -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
        "Money" {
            Add-MoneyAttribute -Connection $connection -TableName $TableName -AttributeLogicalName $attributeLogicalName -AttributeSchemaName $AttributeSchemaName -AttributeDisplayName $AttributeDisplayName -SolutionName $SolutionName -Precision $Precision -MinValue $MinValue -MaxValue $MaxValue -IsRequired $IsRequiredBool -IsAudited $IsAuditedBool -Description $Description
        }
    }
    
    Write-Host "Attribute creation process completed successfully!" -ForegroundColor Green
    Write-Host "Attribute Logical Name: $attributeLogicalName" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
