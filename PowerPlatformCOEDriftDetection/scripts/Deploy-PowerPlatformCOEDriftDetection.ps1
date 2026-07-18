[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$EnvironmentUrl,

    [string]$SchemaPath = (Join-Path $PSScriptRoot "..\dataverse\coe-drift-detection-schema.json"),

    [ValidateSet("AzureCloud", "AzureUSGovernment")]
    [string]$AzEnvironment = "AzureCloud",

    [ValidateSet("GCC", "GCCHigh", "DoD")]
    [string]$Cloud = "GCC",

    [string]$TenantId,

    [string]$GraphTenantId,

    [string]$GraphClientId,

    [securestring]$GraphClientSecret,

    [switch]$SkipEnvironmentVariableValues,

    [string]$AccessToken
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Label {
    param([string]$Text)
    @{
        LocalizedLabels = @(@{ Label = $Text; LanguageCode = 1033 })
        UserLocalizedLabel = @{ Label = $Text; LanguageCode = 1033 }
    }
}

function Get-LogicalName {
    param([string]$SchemaName)
    return $SchemaName.ToLowerInvariant()
}

function Invoke-DataverseRequest {
    param(
        [Parameter(Mandatory)][ValidateSet("GET", "POST", "PATCH")]
        [string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body
    )

    $base = $EnvironmentUrl.TrimEnd("/")
    $uri = if ($Path.StartsWith("http")) { $Path } else { "$base/api/data/v9.2/$Path" }
    $headers = @{
        Authorization      = "Bearer $script:Token"
        Accept             = "application/json"
        "OData-MaxVersion" = "4.0"
        "OData-Version"    = "4.0"
        Prefer             = "return=representation"
    }

    if ($PSBoundParameters.ContainsKey("Body")) {
        $json = $Body | ConvertTo-Json -Depth 25
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType "application/json" -Body $json
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function ConvertFrom-SecureStringToPlainText {
    param([securestring]$SecureValue)

    if (-not $SecureValue) {
        return $null
    }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-AccessToken {
    if ($AccessToken) {
        return $AccessToken
    }

    if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
        Install-Module Az.Accounts -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module Az.Accounts
    if ($TenantId) {
        Connect-AzAccount -Environment $AzEnvironment -TenantId $TenantId | Out-Null
    }
    else {
        Connect-AzAccount -Environment $AzEnvironment | Out-Null
    }

    return (Get-AzAccessToken -ResourceUrl $EnvironmentUrl).Token
}

function Ensure-Publisher {
    param([object]$Solution)

    $uniqueName = $Solution.publisherUniqueName
    $existing = Invoke-DataverseRequest -Method GET -Path "publishers?`$select=publisherid,uniquename&`$filter=uniquename eq '$uniqueName'"
    if ($existing.value.Count -gt 0) {
        return $existing.value[0].publisherid
    }

    $publisher = @{
        uniquename = $uniqueName
        friendlyname = $Solution.publisherDisplayName
        customizationprefix = $Solution.publisherPrefix
        customizationoptionvalueprefix = 94462
    }
    $result = Invoke-DataverseRequest -Method POST -Path "publishers" -Body $publisher
    return $result.publisherid
}

function Ensure-Solution {
    param([object]$Solution, [string]$PublisherId)

    $uniqueName = $Solution.uniqueName
    $existing = Invoke-DataverseRequest -Method GET -Path "solutions?`$select=solutionid,uniquename&`$filter=uniquename eq '$uniqueName'"
    if ($existing.value.Count -gt 0) {
        return $existing.value[0].solutionid
    }

    $body = @{
        uniquename = $Solution.uniqueName
        friendlyname = $Solution.displayName
        version = $Solution.version
        "publisherid@odata.bind" = "/publishers($PublisherId)"
    }
    $created = Invoke-DataverseRequest -Method POST -Path "solutions" -Body $body
    return $created.solutionid
}

function Get-EnvironmentVariableTypeValue {
    param([string]$Type)

    switch ($Type) {
        "String" { return 100000000 }
        "Number" { return 100000001 }
        "Boolean" { return 100000002 }
        "JSON" { return 100000003 }
        "DataSource" { return 100000004 }
        "Secret" { return 100000005 }
        default { throw "Unsupported environment variable type '$Type'." }
    }
}

function Get-CloudDefaults {
    param([string]$CloudName)

    switch ($CloudName) {
        "GCC" {
            return @{
                coe_CloudName = "GCC"
                coe_GraphAuthorityUrl = "https://login.microsoftonline.com"
                coe_GraphAudience = "https://graph.microsoft.com"
                coe_GraphBaseUrl = "https://graph.microsoft.com/v1.0"
                coe_PowerPlatformApiBaseUrl = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform"
            }
        }
        "GCCHigh" {
            return @{
                coe_CloudName = "GCCHigh"
                coe_GraphAuthorityUrl = "https://login.microsoftonline.us"
                coe_GraphAudience = "https://graph.microsoft.us"
                coe_GraphBaseUrl = "https://graph.microsoft.us/v1.0"
                coe_PowerPlatformApiBaseUrl = "https://api.bap.appsplatform.us/providers/Microsoft.BusinessAppPlatform"
            }
        }
        "DoD" {
            return @{
                coe_CloudName = "DoD"
                coe_GraphAuthorityUrl = "https://login.microsoftonline.us"
                coe_GraphAudience = "https://dod-graph.microsoft.us"
                coe_GraphBaseUrl = "https://dod-graph.microsoft.us/v1.0"
                coe_PowerPlatformApiBaseUrl = "https://api.bap.appsplatform.us/providers/Microsoft.BusinessAppPlatform"
            }
        }
        default {
            throw "Unsupported cloud '$CloudName'."
        }
    }
}

function Get-EnvironmentVariableCurrentValues {
    $values = Get-CloudDefaults -CloudName $Cloud
    $effectiveGraphTenantId = if ($GraphTenantId) { $GraphTenantId } else { $TenantId }

    if ($effectiveGraphTenantId) {
        $values["coe_GraphTenantId"] = $effectiveGraphTenantId
    }
    if ($GraphClientId) {
        $values["coe_GraphClientId"] = $GraphClientId
    }
    $secretValue = ConvertFrom-SecureStringToPlainText -SecureValue $GraphClientSecret
    if ($secretValue) {
        $values["coe_GraphClientSecret"] = $secretValue
    }

    return $values
}

function Ensure-EnvironmentVariableDefinition {
    param([object]$Variable, [string]$SolutionUniqueName)

    $schemaName = $Variable.schemaName
    $escapedSchemaName = $schemaName.Replace("'", "''")
    $existing = Invoke-DataverseRequest -Method GET -Path "environmentvariabledefinitions?`$select=environmentvariabledefinitionid,schemaname&`$filter=schemaname eq '$escapedSchemaName'"

    $body = @{
        schemaname = $schemaName
        displayname = $Variable.displayName
        description = $Variable.description
        type = Get-EnvironmentVariableTypeValue -Type $Variable.type
    }
    if ($Variable.PSObject.Properties.Name -contains "defaultValue") {
        $body["defaultvalue"] = $Variable.defaultValue
    }

    if ($existing.value.Count -gt 0) {
        $definitionId = $existing.value[0].environmentvariabledefinitionid
        $updateBody = @{
            displayname = $Variable.displayName
            description = $Variable.description
        }
        if ($Variable.PSObject.Properties.Name -contains "defaultValue") {
            $updateBody["defaultvalue"] = $Variable.defaultValue
        }
        Invoke-DataverseRequest -Method PATCH -Path "environmentvariabledefinitions($definitionId)" -Body $updateBody | Out-Null
    }
    else {
        $created = Invoke-DataverseRequest -Method POST -Path "environmentvariabledefinitions" -Body $body
        $definitionId = $created.environmentvariabledefinitionid
    }

    Add-ComponentToSolution -ComponentId $definitionId -ComponentType 380 -SolutionUniqueName $SolutionUniqueName -ComponentName $schemaName
    return $definitionId
}

function Set-EnvironmentVariableValue {
    param(
        [string]$DefinitionId,
        [string]$SchemaName,
        [string]$Value,
        [string]$SolutionUniqueName
    )

    if ($null -eq $Value -or $Value -eq "") {
        return
    }

    $existing = Invoke-DataverseRequest -Method GET -Path "environmentvariablevalues?`$select=environmentvariablevalueid,value&`$filter=_environmentvariabledefinitionid_value eq $DefinitionId"
    $body = @{
        value = $Value
        "EnvironmentVariableDefinitionId@odata.bind" = "/environmentvariabledefinitions($DefinitionId)"
    }

    if ($existing.value.Count -gt 0) {
        $valueId = $existing.value[0].environmentvariablevalueid
        Invoke-DataverseRequest -Method PATCH -Path "environmentvariablevalues($valueId)" -Body @{ value = $Value } | Out-Null
    }
    else {
        $created = Invoke-DataverseRequest -Method POST -Path "environmentvariablevalues" -Body $body
        $valueId = $created.environmentvariablevalueid
        Add-ComponentToSolution -ComponentId $valueId -ComponentType 381 -SolutionUniqueName $SolutionUniqueName -ComponentName "$SchemaName value"
    }
}

function Ensure-EnvironmentVariables {
    param([object[]]$Variables, [string]$SolutionUniqueName)

    if (-not $Variables) {
        return
    }

    $currentValues = Get-EnvironmentVariableCurrentValues
    foreach ($variable in $Variables) {
        $definitionId = Ensure-EnvironmentVariableDefinition -Variable $variable -SolutionUniqueName $SolutionUniqueName
        if (-not $SkipEnvironmentVariableValues) {
            $schemaName = [string]$variable.schemaName
            if ($currentValues.ContainsKey($schemaName)) {
                Set-EnvironmentVariableValue -DefinitionId $definitionId -SchemaName $schemaName -Value $currentValues[$schemaName] -SolutionUniqueName $SolutionUniqueName
            }
        }
    }
}

function New-OptionSet {
    param([string[]]$Values)

    $options = @()
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $options += @{
            Value = 944620000 + $i
            Label = New-Label -Text $Values[$i]
        }
    }

    return @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OptionSetMetadata"
        IsGlobal = $false
        OptionSetType = "Picklist"
        Options = $options
    }
}

function New-AttributeMetadata {
    param([object]$Column, [object]$Choices, [string]$PrimaryName)

    $isRequired = ($Column.PSObject.Properties.Name -contains "required") -and $Column.required -eq $true
    $requiredLevel = if ($isRequired) { "ApplicationRequired" } else { "None" }
    $common = @{
        SchemaName = $Column.schemaName
        DisplayName = New-Label -Text $Column.displayName
        RequiredLevel = @{ Value = $requiredLevel }
    }

    switch ($Column.type) {
        "string" {
            $maxLength = if ($Column.PSObject.Properties.Name -contains "maxLength") { [int]$Column.maxLength } else { 300 }
            $isPrimaryName = $Column.schemaName -eq $PrimaryName
            return $common + @{
                "@odata.type" = "Microsoft.Dynamics.CRM.StringAttributeMetadata"
                MaxLength = $maxLength
                FormatName = @{ Value = "Text" }
                IsPrimaryName = $isPrimaryName
            }
        }
        "memo" {
            $maxLength = if ($Column.PSObject.Properties.Name -contains "maxLength") { [int]$Column.maxLength } else { 1048576 }
            return $common + @{
                "@odata.type" = "Microsoft.Dynamics.CRM.MemoAttributeMetadata"
                MaxLength = $maxLength
                FormatName = @{ Value = "TextArea" }
            }
        }
        "datetime" {
            return $common + @{
                "@odata.type" = "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata"
                Format = "DateAndTime"
                DateTimeBehavior = @{ Value = "UserLocal" }
            }
        }
        "integer" {
            return $common + @{
                "@odata.type" = "Microsoft.Dynamics.CRM.IntegerAttributeMetadata"
                MinValue = 0
                MaxValue = 2147483647
                Format = "None"
            }
        }
        "boolean" {
            return $common + @{
                "@odata.type" = "Microsoft.Dynamics.CRM.BooleanAttributeMetadata"
                OptionSet = @{
                    TrueOption = @{ Value = 1; Label = New-Label -Text "Yes" }
                    FalseOption = @{ Value = 0; Label = New-Label -Text "No" }
                }
            }
        }
        "choice" {
            return $common + @{
                "@odata.type" = "Microsoft.Dynamics.CRM.PicklistAttributeMetadata"
                OptionSet = New-OptionSet -Values ([string[]]$Choices.$($Column.choice))
            }
        }
        default {
            throw "Unsupported column type '$($Column.type)' for $($Column.schemaName)."
        }
    }
}

function Get-EntityMetadata {
    param([string]$LogicalName)

    return Invoke-DataverseRequest -Method GET -Path "EntityDefinitions(LogicalName='$LogicalName')?`$select=MetadataId,LogicalName"
}

function Wait-EntityMetadata {
    param([string]$LogicalName, [int]$TimeoutSeconds = 180)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            return Get-EntityMetadata -LogicalName $LogicalName
        }
        catch {
            if ((Get-Date) -ge $deadline) {
                throw "Timed out waiting for Dataverse metadata for table '$LogicalName'. Rerun the script after a minute."
            }
            Start-Sleep -Seconds 5
        }
    } while ($true)
}

function Add-EntityToSolution {
    param([string]$MetadataId, [string]$SolutionUniqueName, [string]$LogicalName)

    try {
        Invoke-DataverseRequest -Method POST -Path "AddSolutionComponent" -Body @{
            ComponentId = $MetadataId
            ComponentType = 1
            SolutionUniqueName = $SolutionUniqueName
            AddRequiredComponents = $true
            DoNotIncludeSubcomponents = $false
        } | Out-Null
    }
    catch {
        Write-Warning "Could not add table '$LogicalName' to solution '$SolutionUniqueName'. If it is already in the solution, this warning is safe. Details: $($_.Exception.Message)"
    }
}

function Add-ComponentToSolution {
    param([string]$ComponentId, [int]$ComponentType, [string]$SolutionUniqueName, [string]$ComponentName)

    try {
        Invoke-DataverseRequest -Method POST -Path "AddSolutionComponent" -Body @{
            ComponentId = $ComponentId
            ComponentType = $ComponentType
            SolutionUniqueName = $SolutionUniqueName
            AddRequiredComponents = $true
            DoNotIncludeSubcomponents = $false
        } | Out-Null
    }
    catch {
        Write-Warning "Could not add component '$ComponentName' to solution '$SolutionUniqueName'. If it is already in the solution, this warning is safe. Details: $($_.Exception.Message)"
    }
}

function Ensure-Table {
    param([object]$Table, [object]$Choices, [string]$SolutionUniqueName)

    $logicalName = Get-LogicalName -SchemaName $Table.schemaName
    try {
        $existing = Get-EntityMetadata -LogicalName $logicalName
        Add-EntityToSolution -MetadataId $existing.MetadataId -SolutionUniqueName $SolutionUniqueName -LogicalName $logicalName
        return $existing.MetadataId
    }
    catch {
        Write-Host "Creating table $($Table.displayName)..."
    }

    $primary = ($Table.columns | Where-Object { $_.schemaName -eq $Table.primaryName })[0]
    if (-not $primary) {
        throw "Primary column $($Table.primaryName) was not found for table $($Table.schemaName)."
    }

    $attributes = @()
    foreach ($column in $Table.columns) {
        $attributes += New-AttributeMetadata -Column $column -Choices $Choices -PrimaryName $Table.primaryName
    }

    $entity = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.EntityMetadata"
        SchemaName = $Table.schemaName
        DisplayName = New-Label -Text $Table.displayName
        DisplayCollectionName = New-Label -Text $Table.collectionName
        Description = New-Label -Text "$($Table.displayName) table for Power Platform COE drift detection."
        OwnershipType = $Table.ownership
        IsActivity = $false
        HasActivities = $false
        HasNotes = $true
        Attributes = $attributes
    }

    Invoke-DataverseRequest -Method POST -Path "EntityDefinitions" -Body $entity | Out-Null
    $created = Wait-EntityMetadata -LogicalName $logicalName
    Add-EntityToSolution -MetadataId $created.MetadataId -SolutionUniqueName $SolutionUniqueName -LogicalName $logicalName
    return $created.MetadataId
}

function Ensure-Relationship {
    param([object]$Table, [object[]]$AllTables)

    if (-not ($Table.PSObject.Properties.Name -contains "lookupTo")) {
        return
    }

    $referenced = ($AllTables | Where-Object { $_.schemaName -eq $Table.lookupTo })[0]
    if (-not $referenced) {
        throw "Lookup target $($Table.lookupTo) was not found for $($Table.schemaName)."
    }

    $referencedLogical = Get-LogicalName -SchemaName $referenced.schemaName
    $referencingLogical = Get-LogicalName -SchemaName $Table.schemaName
    $lookupSchema = "$($referenced.schemaName)Id"
    $relationshipSchema = "$($referenced.schemaName)_$($Table.schemaName)"

    try {
        Invoke-DataverseRequest -Method GET -Path "RelationshipDefinitions(SchemaName='$relationshipSchema')?`$select=MetadataId,SchemaName" | Out-Null
        return
    }
    catch {
        Write-Host "Creating relationship $relationshipSchema..."
    }

    $relationship = @{
        "@odata.type" = "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata"
        SchemaName = $relationshipSchema
        ReferencedEntity = $referencedLogical
        ReferencingEntity = $referencingLogical
        Lookup = @{
            "@odata.type" = "Microsoft.Dynamics.CRM.LookupAttributeMetadata"
            SchemaName = $lookupSchema
            DisplayName = New-Label -Text $referenced.displayName
            RequiredLevel = @{ Value = "None" }
        }
        CascadeConfiguration = @{
            Assign = "NoCascade"
            Delete = "RemoveLink"
            Merge = "NoCascade"
            Reparent = "NoCascade"
            Share = "NoCascade"
            Unshare = "NoCascade"
        }
        AssociatedMenuConfiguration = @{
            Behavior = "UseCollectionName"
            Group = "Details"
            Label = New-Label -Text $Table.collectionName
            Order = 10000
        }
    }

    Invoke-DataverseRequest -Method POST -Path "RelationshipDefinitions" -Body $relationship | Out-Null
}

function Publish-Customizations {
    Invoke-DataverseRequest -Method POST -Path "PublishAllXml" -Body @{} | Out-Null
}

$schema = Get-Content -Raw -Path $SchemaPath | ConvertFrom-Json
$script:Token = Get-AccessToken

Write-Host "Deploying $($schema.solution.displayName) to $EnvironmentUrl..."
$publisherId = Ensure-Publisher -Solution $schema.solution
$null = Ensure-Solution -Solution $schema.solution -PublisherId $publisherId

Ensure-EnvironmentVariables -Variables $schema.environmentVariables -SolutionUniqueName $schema.solution.uniqueName

foreach ($table in $schema.tables) {
    $null = Ensure-Table -Table $table -Choices $schema.choices -SolutionUniqueName $schema.solution.uniqueName
}

foreach ($table in $schema.tables) {
    Ensure-Relationship -Table $table -AllTables $schema.tables
}

Publish-Customizations
Write-Host "Deployment complete. Solution: $($schema.solution.uniqueName)"
