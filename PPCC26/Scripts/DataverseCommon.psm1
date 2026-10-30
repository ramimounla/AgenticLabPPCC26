#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Base script with common functions for Dataverse operations.

.DESCRIPTION
    This script contains common functions used across multiple Dataverse scripts,
    including connection management, solution verification, and entity/attribute validation.

.NOTES
    Requires the Microsoft.PowerApps.Administration.PowerShell and Microsoft.Xrm.Data.PowerShell modules.
    Run 'Install-Module -Name Microsoft.PowerApps.Administration.PowerShell' if needed.
    Run 'Install-Module -Name Microsoft.Xrm.Data.PowerShell' if needed.
#>

# Connection object (will be set when Connect-ToDataverse is called)
$script:DataverseConnection = $null

function Import-RequiredModules {
    [CmdletBinding()]
    param()
    
    # Check for required modules
    $requiredModules = @("Microsoft.PowerApps.Administration.PowerShell", "Microsoft.Xrm.Data.PowerShell")
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Required module $module is not installed. Installing..." -ForegroundColor Yellow
            Install-Module -Name $module -Scope CurrentUser -Force
        }
    }
    
    # Import modules
    Import-Module Microsoft.PowerApps.Administration.PowerShell
    Import-Module Microsoft.Xrm.Data.PowerShell
}

function Connect-ToDataverse {
    [CmdletBinding()]
    param()

    Write-Host "Connecting to Dataverse environment using connection string..." -ForegroundColor Cyan

    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    $ServerUrl = $config.target.ServerUrl

    $ClientIdValue = "744835ed-bebe-4658-ac23-93173fc916ef"
    $SecretValue = "N2R8Q~_IX_GPGgN0OZdmOb70v_sOUKITfA5IzcKX"

    $script:DataverseConnectionString = "AuthType=ClientSecret;ServiceUri=$($ServerUrl);ClientId=$($ClientIdValue);ClientSecret=$($SecretValue)";

    try {
        $conn = Get-CrmConnection -ConnectionString $script:DataverseConnectionString -ErrorAction Stop
        if ($conn) {
            Write-Host "Successfully connected to: $($conn.ConnectedOrgFriendlyName)" -ForegroundColor Green
            $script:DataverseConnection = $conn
            return $conn
        }
        else {
            throw "Failed to establish connection to Dataverse environment"
        }
    }
    catch {
        Write-Error "Failed to connect to Dataverse environment: $_"
        exit 1
    }
}

function Get-DataverseConnection {
    [CmdletBinding()]
    param()

    if ($null -eq $script:DataverseConnection) {
        return Connect-ToDataverse
    }
    else {
        return $script:DataverseConnection
    }
}

function Confirm-SolutionExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName
    )

    Write-Host "Verifying solution '$SolutionName' exists..." -ForegroundColor Yellow
    
    # Check if solution exists
    $fetchXml = @"
    <fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
      <entity name="solution">
        <attribute name="uniquename" />
        <attribute name="friendlyname" />
        <filter type="and">
          <condition attribute="uniquename" operator="eq" value="$SolutionName" />
        </filter>
      </entity>
    </fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetchXml
    
    if ($result.CrmRecords.Count -eq 0) {
        Write-Error "Solution '$SolutionName' does not exist. Please create the solution first."
        return $false
    }
    
    Write-Host "Solution '$SolutionName' found: $($result.CrmRecords[0].friendlyname)" -ForegroundColor Green
    return $true
}

function Get-CustomizationPrefix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$SolutionName
    )

    Write-Host "Retrieving customization prefix for solution '$SolutionName'..." -ForegroundColor Yellow
    
    # Get the publisher for the solution
    $fetchXml = @"
    <fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
      <entity name="solution">
        <attribute name="publisherid" />
        <filter type="and">
          <condition attribute="uniquename" operator="eq" value="$SolutionName" />
        </filter>
      </entity>
    </fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetchXml
    
    if ($result.CrmRecords.Count -eq 0) {
        Write-Error "Solution '$SolutionName' does not exist."
        return $null
    }
    
    $publisherId = $result.CrmRecords[0].publisherid_Property.Value.Id
    
    # Get the prefix from the publisher
    $fetchXml = @"
    <fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
      <entity name="publisher">
        <attribute name="customizationprefix" />
        <filter type="and">
          <condition attribute="publisherid" operator="eq" value="$publisherId" />
        </filter>
      </entity>
    </fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetchXml
    
    if ($result.CrmRecords.Count -eq 0) {
        Write-Error "Publisher for solution '$SolutionName' does not exist."
        return $null
    }
    
    $prefix = $result.CrmRecords[0].customizationprefix
    Write-Host "Customization prefix for solution '$SolutionName' is '$prefix'" -ForegroundColor Green
    return $prefix
}

function Test-TableExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableLogicalName
    )

    Write-Host "Checking if table '$TableLogicalName' exists..." -ForegroundColor Yellow
    
    try {
        $request = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveEntityRequest
        $request.LogicalName = $TableLogicalName
        $request.EntityFilters = [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Entity
        $request.RetrieveAsIfPublished = $true
        
        $response = $Connection.Execute($request)
        
        if ($null -ne $response) {
            Write-Host "Table '$TableLogicalName' exists." -ForegroundColor Green
            return $true
        }
    }
    catch {
        # If exception is thrown, the entity doesn't exist
        Write-Host "Table '$TableLogicalName' does not exist." -ForegroundColor Yellow
        return $false
    }
    
    return $false
}

function Test-AttributeExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection = (Get-DataverseConnection),
        
        [Parameter(Mandatory = $true)]
        [string]$TableName,
        
        [Parameter(Mandatory = $true)]
        [string]$AttributeLogicalName
    )

    Write-Host "Checking if attribute '$AttributeLogicalName' already exists in table '$TableName'..." -ForegroundColor Yellow
    
    try {
        $request = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveAttributeRequest
        $request.EntityLogicalName = $TableName
        $request.LogicalName = $AttributeLogicalName
        $request.RetrieveAsIfPublished = $true
        
        $response = $Connection.Execute($request)
        
        if ($null -ne $response) {
            Write-Host "Attribute '$AttributeLogicalName' already exists in table '$TableName'." -ForegroundColor Yellow
            return $true
        }
    }
    catch {
        # If exception is thrown, the attribute doesn't exist
        Write-Verbose "Attribute doesn't exist. Will create a new one."
        return $false
    }
    
    return $false
}

function Format-TableOrAttributeName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Prefix,
        
        [Parameter(Mandatory = $false)]
        [switch]$ToLower = $false
    )
    
    # Remove spaces and special characters
    $cleanName = $Name -replace '[^a-zA-Z0-9]', ''
    
    # Add prefix if not already there
    if (-not $cleanName.StartsWith($Prefix + "_")) {
        $prefixedName = $Prefix + "_" + $cleanName
    } else {
        $prefixedName = $cleanName
    }
    
    # Convert to lowercase if specified
    if ($ToLower) {
        return $prefixedName.ToLower()
    } else {
        return $prefixedName
    }
}

# Export functions to make them available to other scripts
Export-ModuleMember -Function Import-RequiredModules, Connect-ToDataverse, Get-DataverseConnection, Confirm-SolutionExists, Get-CustomizationPrefix, Test-TableExists, Test-AttributeExists, Format-TableOrAttributeName
