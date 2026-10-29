#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Exports a ppcc_eventtrigger record (and its rule groups, conditions and actions) to the
    event JSON structure documented in .github\agents\createevent.agent.md.

.DESCRIPTION
    Finds a single ppcc_eventtrigger by name (partial match) or by GUID, then reads its
    child ppcc_rulegroup records and each rule group's ppcc_rulecondition/ppcc_ruleaction
    records, and writes the result as a hierarchical JSON file.

.PARAMETER EventName
    Partial or full display name of the event trigger (ppcc_name) to search for.

.PARAMETER EventTriggerId
    The GUID (ppcc_eventtriggerid) of the event trigger to export.

.PARAMETER OutputPath
    Optional. Path of the JSON file to write. Only valid when exactly one event trigger
    is matched. If not specified, saves to Requirement\events\<EventName>.json at the workspace root.

.EXAMPLE
    .\Export-EventTrigger.ps1 -EventName "Case Escalation SLA"

.EXAMPLE
    .\Export-EventTrigger.ps1 -EventTriggerId "5b6a1e2a-1111-2222-3333-444455556666" -OutputPath "C:\Temp\event.json"
#>

[CmdletBinding(DefaultParameterSetName = "ByName")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "ByName")]
    [string]$EventName,

    [Parameter(Mandatory = $true, ParameterSetName = "ById")]
    [string]$EventTriggerId,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

$script:CachingFolder = Join-Path (Split-Path $PSScriptRoot -Parent) 'Requirement\caching'
$script:ChoiceMaps = @{}

function Get-ChoiceMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$TableName,
        [Parameter(Mandatory = $true)] [string]$AttributeName
    )

    $cacheKey = "$TableName.$AttributeName"
    if ($script:ChoiceMaps.ContainsKey($cacheKey)) { return $script:ChoiceMaps[$cacheKey] }

    $choicesPath = Join-Path $script:CachingFolder "$($TableName)_Choices.json"
    $map = @{}
    if (Test-Path $choicesPath) {
        $choicesJson = Get-Content -Path $choicesPath -Raw | ConvertFrom-Json
        $attrChoices = $choicesJson.choices.$AttributeName
        if ($attrChoices) {
            foreach ($property in $attrChoices.PSObject.Properties) {
                $map[$property.Name] = $property.Value
            }
        }
    }
    else {
        Write-Warning "Cached choices file not found: $choicesPath. Picklist labels for $cacheKey will fall back to raw values."
    }

    $script:ChoiceMaps[$cacheKey] = $map
    return $map
}

function Get-ChoiceLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [psobject]$Record,
        [Parameter(Mandatory = $true)] [string]$Attr,
        [Parameter(Mandatory = $true)] [string]$TableName
    )

    $rawValue = Get-AttrValue -Record $Record -Attr $Attr
    if ($null -eq $rawValue -or $rawValue -eq '') { return "" }

    $map = Get-ChoiceMap -TableName $TableName -AttributeName $Attr
    $key = [string]$rawValue
    if ($map.ContainsKey($key)) { return $map[$key] }

    Write-Warning "No cached choice label found for $TableName.$Attr value '$rawValue'. Using raw value."
    return $key
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

function Get-AttrString {
    param(
        [Parameter(Mandatory = $true)] [psobject]$Record,
        [Parameter(Mandatory = $true)] [string]$Attr
    )
    $value = Get-AttrValue -Record $Record -Attr $Attr
    if ($null -eq $value) { return "" }
    return [string]$value
}

function Get-AttrBool {
    param(
        [Parameter(Mandatory = $true)] [psobject]$Record,
        [Parameter(Mandatory = $true)] [string]$Attr
    )
    $value = Get-AttrValue -Record $Record -Attr $Attr
    if ($null -eq $value) { return $false }
    return [bool]$value
}

function Get-AttrInt {
    param(
        [Parameter(Mandatory = $true)] [psobject]$Record,
        [Parameter(Mandatory = $true)] [string]$Attr
    )
    $value = Get-AttrValue -Record $Record -Attr $Attr
    if ($null -eq $value) { return 0 }
    return [int]$value
}

function Get-EventTriggers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection
    )

    if ($EventTriggerId) {
        $filter = "<condition attribute='ppcc_eventtriggerid' operator='eq' value='$EventTriggerId' />"
    }
    else {
        $filter = "<condition attribute='ppcc_name' operator='like' value='%$EventName%' />"
    }

    $fetch = @"
<fetch version='1.0' mapping='logical'>
  <entity name='ppcc_eventtrigger'>
    <attribute name='ppcc_eventtriggerid' />
    <attribute name='ppcc_name' />
    <attribute name='ppcc_description' />
    <attribute name='ppcc_table' />
    <attribute name='ppcc_attributes' />
    <attribute name='ppcc_preimageattributes' />
    <attribute name='ppcc_message' />
    <attribute name='ppcc_stage' />
    <attribute name='ppcc_executeallrules' />
    <attribute name='ppcc_order' />
    <filter type='and'>
      $filter
    </filter>
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetch
    return $result.CrmRecords
}

function Get-RuleGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$EventTriggerRecordId
    )

    $fetch = @"
<fetch version='1.0' mapping='logical'>
  <entity name='ppcc_rulegroup'>
    <attribute name='ppcc_rulegroupid' />
    <attribute name='ppcc_name' />
    <attribute name='ppcc_order' />
    <filter type='and'>
      <condition attribute='ppcc_eventtriggerid' operator='eq' value='$EventTriggerRecordId' />
    </filter>
    <order attribute='ppcc_order' />
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetch
    return $result.CrmRecords
}

function Get-RuleConditions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$RuleGroupRecordId
    )

    $fetch = @"
<fetch version='1.0' mapping='logical'>
  <entity name='ppcc_rulecondition'>
    <attribute name='ppcc_ruleconditionid' />
    <attribute name='ppcc_name' />
    <attribute name='ppcc_fieldname' />
    <attribute name='ppcc_incomingattribute' />
    <attribute name='ppcc_operand' />
    <attribute name='ppcc_value' />
    <attribute name='ppcc_valuelabel' />
    <attribute name='ppcc_order' />
    <filter type='and'>
      <condition attribute='ppcc_rulegroupid' operator='eq' value='$RuleGroupRecordId' />
    </filter>
    <order attribute='ppcc_order' />
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetch
    return $result.CrmRecords
}

function Get-RuleActions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$RuleGroupRecordId
    )

    $fetch = @"
<fetch version='1.0' mapping='logical'>
  <entity name='ppcc_ruleaction'>
    <attribute name='ppcc_ruleactionid' />
    <attribute name='ppcc_name' />
    <attribute name='ppcc_actiontype' />
    <attribute name='ppcc_destinationattribute' />
    <attribute name='ppcc_referenceattribute' />
    <attribute name='ppcc_directivesjson' />
    <attribute name='ppcc_value' />
    <attribute name='ppcc_order' />
    <filter type='and'>
      <condition attribute='ppcc_rulegroupid' operator='eq' value='$RuleGroupRecordId' />
    </filter>
    <order attribute='ppcc_order' />
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetch
    return $result.CrmRecords
}

function ConvertTo-EventJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,

        [Parameter(Mandatory = $true)]
        [psobject]$EventTrigger
    )

    $eventTriggerId = Get-AttrString -Record $EventTrigger -Attr 'ppcc_eventtriggerid'

    $ruleGroupRecords = Get-RuleGroups -Connection $Connection -EventTriggerRecordId $eventTriggerId

    $ruleGroups = @()
    foreach ($ruleGroup in $ruleGroupRecords) {
        $ruleGroupId = Get-AttrString -Record $ruleGroup -Attr 'ppcc_rulegroupid'

        $conditions = @()
        foreach ($condition in (Get-RuleConditions -Connection $Connection -RuleGroupRecordId $ruleGroupId)) {
            $conditions += [PSCustomObject]@{
                name                = Get-AttrString -Record $condition -Attr 'ppcc_name'
                fieldName           = Get-AttrString -Record $condition -Attr 'ppcc_fieldname'
                incomingAttribute   = Get-AttrBool -Record $condition -Attr 'ppcc_incomingattribute'
                operand             = Get-ChoiceLabel -Record $condition -Attr 'ppcc_operand' -TableName 'ppcc_rulecondition'
                value               = Get-AttrString -Record $condition -Attr 'ppcc_value'
                valueLabel          = Get-AttrString -Record $condition -Attr 'ppcc_valuelabel'
                order               = Get-AttrInt -Record $condition -Attr 'ppcc_order'
            }
        }

        $actions = @()
        foreach ($action in (Get-RuleActions -Connection $Connection -RuleGroupRecordId $ruleGroupId)) {
            $actions += [PSCustomObject]@{
                name                  = Get-AttrString -Record $action -Attr 'ppcc_name'
                actionType            = Get-ChoiceLabel -Record $action -Attr 'ppcc_actiontype' -TableName 'ppcc_ruleaction'
                destinationAttribute  = Get-AttrString -Record $action -Attr 'ppcc_destinationattribute'
                referenceAttribute    = Get-AttrString -Record $action -Attr 'ppcc_referenceattribute'
                value                 = Get-AttrString -Record $action -Attr 'ppcc_value'
                directivesJson        = Get-AttrString -Record $action -Attr 'ppcc_directivesjson'
                order                 = Get-AttrInt -Record $action -Attr 'ppcc_order'
            }
        }

        $ruleGroups += [PSCustomObject]@{
            name       = Get-AttrString -Record $ruleGroup -Attr 'ppcc_name'
            order      = Get-AttrInt -Record $ruleGroup -Attr 'ppcc_order'
            conditions = $conditions
            actions    = $actions
        }
    }

    $event = [PSCustomObject]@{
        name              = Get-AttrString -Record $EventTrigger -Attr 'ppcc_name'
        description       = Get-AttrString -Record $EventTrigger -Attr 'ppcc_description'
        table             = Get-AttrString -Record $EventTrigger -Attr 'ppcc_table'
        attributes        = Get-AttrString -Record $EventTrigger -Attr 'ppcc_attributes'
        preImageAttributes = Get-AttrString -Record $EventTrigger -Attr 'ppcc_preimageattributes'
        message           = Get-ChoiceLabel -Record $EventTrigger -Attr 'ppcc_message' -TableName 'ppcc_eventtrigger'
        stage             = Get-ChoiceLabel -Record $EventTrigger -Attr 'ppcc_stage' -TableName 'ppcc_eventtrigger'
        executeAllRules   = Get-AttrBool -Record $EventTrigger -Attr 'ppcc_executeallrules'
        order             = Get-AttrInt -Record $EventTrigger -Attr 'ppcc_order'
        ruleGroups        = $ruleGroups
    }

    return [PSCustomObject]@{ event = $event }
}

try {
    Import-RequiredModules
    $conn = Connect-ToDataverse

    Write-Host "Searching for event trigger(s)..." -ForegroundColor Yellow
    $eventTriggers = Get-EventTriggers -Connection $conn

    if (-not $eventTriggers -or $eventTriggers.Count -eq 0) {
        throw "No ppcc_eventtrigger record found matching the given criteria."
    }

    if ($eventTriggers.Count -gt 1 -and $OutputPath) {
        throw "Multiple event triggers ($($eventTriggers.Count)) matched '$EventName'. Re-run with a more specific -EventName, or omit -OutputPath to export each match to the default Requirement\events folder."
    }

    $eventsFolder = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'Requirement\events'
    if (-not (Test-Path $eventsFolder)) {
        New-Item -ItemType Directory -Path $eventsFolder -Force | Out-Null
    }

    foreach ($eventTrigger in $eventTriggers) {
        $name = Get-AttrString -Record $eventTrigger -Attr 'ppcc_name'
        Write-Host "Exporting event trigger '$name'..." -ForegroundColor Yellow

        $json = ConvertTo-EventJson -Connection $conn -EventTrigger $eventTrigger

        if ($OutputPath) {
            $filePath = $OutputPath
        }
        else {
            $safeName = ($name -replace '[^a-zA-Z0-9 _-]', '') -replace '\s+', ''
            $filePath = Join-Path $eventsFolder ("{0}.json" -f $safeName)
        }

        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

        Write-Host "Saved to: $filePath" -ForegroundColor Green
    }

    Write-Host "`nOperation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
