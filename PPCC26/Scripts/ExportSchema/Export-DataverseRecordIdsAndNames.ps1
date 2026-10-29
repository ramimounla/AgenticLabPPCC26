#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TableName
)

# Use shared helpers
Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

function Get-EntityPrimaryAttributes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$EntityLogicalName
    )

    $req = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveEntityRequest
    $req.LogicalName = $EntityLogicalName
    $req.EntityFilters = [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Entity
    $req.RetrieveAsIfPublished = $true

    $res = $Connection.Execute($req)
    if (-not $res) { throw "Failed to retrieve entity metadata for '$EntityLogicalName'" }

    return [PSCustomObject]@{
        PrimaryIdAttribute   = $res.EntityMetadata.PrimaryIdAttribute
        PrimaryNameAttribute = $res.EntityMetadata.PrimaryNameAttribute
    }
}

function Get-AttrValue {
    param(
        [Parameter(Mandatory = $true)] [psobject]$Record,
        [Parameter(Mandatory = $true)] [string]$Attr
    )
    if ($Record.PSObject.Properties.Match($Attr).Count -gt 0) { return $Record.$Attr }
    $vName = "$Attr`_Value"
    if ($Record.PSObject.Properties.Match($vName).Count -gt 0) { return $Record.$vName }
    $pName = "$Attr`_Property"
    if ($Record.PSObject.Properties.Match($pName).Count -gt 0) {
        $prop = $Record.$pName
        if ($null -ne $prop) {
            if ($prop.PSObject.Properties.Match('Value').Count -gt 0) { return $prop.Value }
            if ($prop.PSObject.Properties.Match('Id').Count -gt 0) { return $prop.Id }
        }
    }
    return $null
}

try {
    Import-RequiredModules
    $conn = Connect-ToDataverse

    if (-not (Test-TableExists -TableLogicalName $TableName)) {
        throw "The specified table '$TableName' does not exist."
    }

    $entityInfo = Get-EntityPrimaryAttributes -Connection $conn -EntityLogicalName $TableName
    $primaryId = $entityInfo.PrimaryIdAttribute
    $primaryName = $entityInfo.PrimaryNameAttribute

    if ([string]::IsNullOrWhiteSpace($primaryName)) {
        throw "Could not determine primary name attribute for table '$TableName'"
    }

    Write-Host "Fetching records for '$TableName' (Id: $primaryId, Name: $primaryName) ..." -ForegroundColor Yellow

    $fetch = @"
<fetch version='1.0' mapping='logical' count='500'>
  <entity name='$TableName'>
    <attribute name='$primaryId' />
    <attribute name='$primaryName' />
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $conn -Fetch $fetch

    $rows = @()
    if ($result -and $result.CrmRecords) {
        foreach ($r in $result.CrmRecords) {
            $rows += [PSCustomObject]@{
                Id   = (Get-AttrValue -Record $r -Attr $primaryId)
                Name = (Get-AttrValue -Record $r -Attr $primaryName)
            }
        }
    }

    $root = (Split-Path $PSScriptRoot -Parent)
    $schemaFolder = Join-Path $root 'Schema'
    if (-not (Test-Path $schemaFolder)) { New-Item -ItemType Directory -Path $schemaFolder -Force | Out-Null }

    $outPath = Join-Path $schemaFolder ("{0}_extract.csv" -f $TableName)
    $rows | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8

    Write-Host ("Exported {0} records to {1}" -f $rows.Count, $outPath) -ForegroundColor Green
}
catch {
    Write-Error $_
    exit 1
}