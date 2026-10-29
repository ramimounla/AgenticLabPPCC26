#Requires -Modules Microsoft.PowerApps.Administration.PowerShell, Microsoft.Xrm.Data.PowerShell

<#
.SYNOPSIS
    Imports the event JSON structure documented in .github\agents\createevent.agent.md
    (a ppcc_eventtrigger record plus its rule groups, conditions and actions) into Dataverse.

.DESCRIPTION
    The reverse of Export-EventTrigger.ps1. Reads an event JSON file, resolves picklist
    labels (message/stage/operand/actiontype) back to their raw option set values using
    the cached choices files under Requirement\caching, then creates the ppcc_eventtrigger
    record and its child ppcc_rulegroup / ppcc_rulecondition / ppcc_ruleaction records.

.PARAMETER Path
    Path to the event JSON file. If not rooted, it is resolved relative to
    Requirement\events at the workspace root (e.g. -Path "TriageTeamAssignment.json").

.PARAMETER Force
    If a ppcc_eventtrigger with the same ppcc_name already exists, delete it (and its rule
    groups/conditions/actions) before importing. Without -Force, an existing match stops
    the import.

.EXAMPLE
    .\Import-EventTrigger.ps1 -Path "TriageTeamAssignment.json"

.EXAMPLE
    .\Import-EventTrigger.ps1 -Path "C:\Temp\event.json" -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path = "TriageTeamAssignment.json",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Import-Module "$PSScriptRoot\..\DataverseCommon.psm1" -Force

$script:CachingFolder = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'Caching'
$script:ChoiceValueMaps = @{}

function Get-ChoiceValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$TableName,
        [Parameter(Mandatory = $true)] [string]$AttributeName,
        [Parameter(Mandatory = $true)] [string]$Label
    )

    $cacheKey = "$TableName.$AttributeName"
    if (-not $script:ChoiceValueMaps.ContainsKey($cacheKey)) {
        $choicesPath = Join-Path $script:CachingFolder "$($TableName)_Choices.json"
        $map = @{}
        if (Test-Path $choicesPath) {
            $choicesJson = Get-Content -Path $choicesPath -Raw | ConvertFrom-Json
            $attrChoices = $choicesJson.choices.$AttributeName
            if ($attrChoices) {
                foreach ($property in $attrChoices.PSObject.Properties) {
                    if ($map.ContainsKey($property.Value)) {
                        Write-Warning "Duplicate choice label '$($property.Value)' for $cacheKey - keeping first match."
                    }
                    else {
                        $map[$property.Value] = $property.Name
                    }
                }
            }
        }
        else {
            Write-Warning "Cached choices file not found: $choicesPath. Cannot resolve labels for $cacheKey."
        }
        $script:ChoiceValueMaps[$cacheKey] = $map
    }

    $map = $script:ChoiceValueMaps[$cacheKey]
    if ($map.ContainsKey($Label)) { return [int]$map[$Label] }

    throw "Choice label '$Label' not found for $cacheKey. Check $($TableName)_Choices.json and the event JSON for a typo."
}

function Test-FlatDirectivesJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ActionName,
        [Parameter(Mandatory = $false)] [string]$DirectivesJson
    )

    if ([string]::IsNullOrWhiteSpace($DirectivesJson)) { return }

    try {
        $parsed = $DirectivesJson | ConvertFrom-Json
    }
    catch {
        Write-Warning "Action '$ActionName': directivesJson is not valid JSON - it will be imported as-is."
        return
    }

    foreach ($property in $parsed.PSObject.Properties) {
        if ($property.Value -is [System.Management.Automation.PSCustomObject] -or $property.Value -is [System.Array]) {
            Write-Warning "Action '$ActionName': directivesJson key '$($property.Name)' is nested - the runtime parser only understands flat string key/value pairs and will ignore it."
        }
    }
}

function Get-ExistingEventTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [string]$EventName
    )

    $fetch = @"
<fetch version='1.0' mapping='logical'>
  <entity name='ppcc_eventtrigger'>
    <attribute name='ppcc_eventtriggerid' />
    <attribute name='ppcc_name' />
    <filter type='and'>
      <condition attribute='ppcc_name' operator='eq' value='$EventName' />
    </filter>
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetch
    return $result.CrmRecords
}

function Get-ChildRecordIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [string]$EntityLogicalName,
        [Parameter(Mandatory = $true)] [string]$IdAttribute,
        [Parameter(Mandatory = $true)] [string]$LookupAttribute,
        [Parameter(Mandatory = $true)] [string]$LookupValue
    )

    $fetch = @"
<fetch version='1.0' mapping='logical'>
  <entity name='$EntityLogicalName'>
    <attribute name='$IdAttribute' />
    <filter type='and'>
      <condition attribute='$LookupAttribute' operator='eq' value='$LookupValue' />
    </filter>
  </entity>
</fetch>
"@

    $result = Get-CrmRecordsByFetch -conn $Connection -Fetch $fetch
    return $result.CrmRecords | ForEach-Object { $_.$IdAttribute }
}

function Remove-ExistingEventTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [string]$EventTriggerId
    )

    $ruleGroupIds = Get-ChildRecordIds -Connection $Connection -EntityLogicalName 'ppcc_rulegroup' -IdAttribute 'ppcc_rulegroupid' -LookupAttribute 'ppcc_eventtriggerid' -LookupValue $EventTriggerId

    foreach ($ruleGroupId in $ruleGroupIds) {
        $conditionIds = Get-ChildRecordIds -Connection $Connection -EntityLogicalName 'ppcc_rulecondition' -IdAttribute 'ppcc_ruleconditionid' -LookupAttribute 'ppcc_rulegroupid' -LookupValue $ruleGroupId
        foreach ($id in $conditionIds) { Remove-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_rulecondition' -Id $id | Out-Null }

        $actionIds = Get-ChildRecordIds -Connection $Connection -EntityLogicalName 'ppcc_ruleaction' -IdAttribute 'ppcc_ruleactionid' -LookupAttribute 'ppcc_rulegroupid' -LookupValue $ruleGroupId
        foreach ($id in $actionIds) { Remove-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_ruleaction' -Id $id | Out-Null }

        Remove-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_rulegroup' -Id $ruleGroupId | Out-Null
    }

    Remove-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_eventtrigger' -Id $EventTriggerId | Out-Null
}

function New-EventTriggerRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [psobject]$Event
    )

    $fields = @{
        ppcc_name              = $Event.name
        ppcc_description       = $Event.description
        ppcc_table             = $Event.table
        ppcc_attributes        = $Event.attributes
        ppcc_preimageattributes = $Event.preImageAttributes
        ppcc_message           = (New-CrmOptionSetValue (Get-ChoiceValue -TableName 'ppcc_eventtrigger' -AttributeName 'ppcc_message' -Label $Event.message))
        ppcc_stage             = (New-CrmOptionSetValue (Get-ChoiceValue -TableName 'ppcc_eventtrigger' -AttributeName 'ppcc_stage' -Label $Event.stage))
        ppcc_executeallrules   = [bool]$Event.executeAllRules
        ppcc_order             = [int]$Event.order
    }

    return New-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_eventtrigger' -Fields $fields
}

function New-RuleGroupRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [psobject]$RuleGroup,
        [Parameter(Mandatory = $true)] [Guid]$EventTriggerId
    )

    $fields = @{
        ppcc_name          = $RuleGroup.name
        ppcc_order         = [int]$RuleGroup.order
        ppcc_eventtriggerid = (New-CrmEntityReference -EntityLogicalName 'ppcc_eventtrigger' -Id $EventTriggerId)
    }

    return New-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_rulegroup' -Fields $fields
}

function New-RuleConditionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [psobject]$Condition,
        [Parameter(Mandatory = $true)] [Guid]$RuleGroupId
    )

    if ($Condition.PSObject.Properties.Match('status').Count -gt 0 -and $Condition.status) {
        Write-Warning "Condition '$($Condition.name)': $($Condition.status)"
    }

    $fields = @{
        ppcc_name              = $Condition.name
        ppcc_fieldname         = $Condition.fieldName
        ppcc_incomingattribute = [bool]$Condition.incomingAttribute
        ppcc_operand           = (New-CrmOptionSetValue (Get-ChoiceValue -TableName 'ppcc_rulecondition' -AttributeName 'ppcc_operand' -Label $Condition.operand))
        ppcc_value             = $Condition.value
        ppcc_valuelabel        = $Condition.valueLabel
        ppcc_order             = [int]$Condition.order
        ppcc_rulegroupid       = (New-CrmEntityReference -EntityLogicalName 'ppcc_rulegroup' -Id $RuleGroupId)
    }

    return New-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_rulecondition' -Fields $fields
}

function New-RuleActionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]$Connection,
        [Parameter(Mandatory = $true)] [psobject]$Action,
        [Parameter(Mandatory = $true)] [Guid]$RuleGroupId
    )

    if ($Action.PSObject.Properties.Match('status').Count -gt 0 -and $Action.status) {
        Write-Warning "Action '$($Action.name)': $($Action.status)"
    }

    Test-FlatDirectivesJson -ActionName $Action.name -DirectivesJson $Action.directivesJson

    $fields = @{
        ppcc_name                 = $Action.name
        ppcc_actiontype           = (New-CrmOptionSetValue (Get-ChoiceValue -TableName 'ppcc_ruleaction' -AttributeName 'ppcc_actiontype' -Label $Action.actionType))
        ppcc_destinationattribute = $Action.destinationAttribute
        ppcc_referenceattribute   = $Action.referenceAttribute
        ppcc_value                = $Action.value
        ppcc_directivesjson       = $Action.directivesJson
        ppcc_order                = [int]$Action.order
        ppcc_rulegroupid          = (New-CrmEntityReference -EntityLogicalName 'ppcc_rulegroup' -Id $RuleGroupId)
    }

    return New-CrmRecord -conn $Connection -EntityLogicalName 'ppcc_ruleaction' -Fields $fields
}

try {
    if ([System.IO.Path]::IsPathRooted($Path)) {
            # Path is already absolute, use it as-is
            $filePath = $Path
        }
        else {
            # Path is relative - resolve it from the project root (Scripts/../..)
            $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $filePath = Join-Path $projectRoot $Path
        }

    if (-not (Test-Path $filePath)) {
        throw "Event JSON file not found: $filePath"
    }

    Write-Host "Reading event JSON from: $filePath" -ForegroundColor Yellow
    $eventJson = Get-Content -Path $filePath -Raw | ConvertFrom-Json
    $event = $eventJson.event

    if (-not $event) {
        throw "The JSON file does not contain a top-level 'event' object."
    }

    Import-RequiredModules
    $conn = Connect-ToDataverse

    $existing = Get-ExistingEventTrigger -Connection $conn -EventName $event.name
    if ($existing -and $existing.Count -gt 0) {
        if (-not $Force) {
            throw "A ppcc_eventtrigger named '$($event.name)' already exists. Re-run with -Force to delete and recreate it, or rename the event."
        }

        foreach ($record in $existing) {
            $existingId = $record.ppcc_eventtriggerid
            Write-Host "Deleting existing event trigger '$($event.name)' ($existingId) and its rule groups/conditions/actions..." -ForegroundColor Yellow
            Remove-ExistingEventTrigger -Connection $conn -EventTriggerId $existingId
        }
    }

    Write-Host "Creating event trigger '$($event.name)'..." -ForegroundColor Yellow
    $eventTriggerId = New-EventTriggerRecord -Connection $conn -Event $event
    Write-Host "Created ppcc_eventtrigger: $eventTriggerId" -ForegroundColor Green

    foreach ($ruleGroup in $event.ruleGroups) {
        Write-Host "  Creating rule group '$($ruleGroup.name)'..." -ForegroundColor Yellow
        $ruleGroupId = New-RuleGroupRecord -Connection $conn -RuleGroup $ruleGroup -EventTriggerId $eventTriggerId

        foreach ($condition in $ruleGroup.conditions) {
            $conditionId = New-RuleConditionRecord -Connection $conn -Condition $condition -RuleGroupId $ruleGroupId
            Write-Host "    Created condition '$($condition.name)': $conditionId" -ForegroundColor DarkGray
        }

        foreach ($action in $ruleGroup.actions) {
            $actionId = New-RuleActionRecord -Connection $conn -Action $action -RuleGroupId $ruleGroupId
            Write-Host "    Created action '$($action.name)': $actionId" -ForegroundColor DarkGray
        }
    }

    Write-Host "`nOperation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
