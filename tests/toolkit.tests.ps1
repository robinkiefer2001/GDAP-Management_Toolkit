$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

function assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}

$automaticVariables = @('PSScriptRoot', 'PSBoundParameters', 'ErrorActionPreference', 'WebEvent')
foreach ($file in Get-ChildItem (Join-Path $root 'public') -Filter '*.html') {
    $html = Get-Content $file.FullName -Raw
    $ids = @([regex]::Matches($html, '\bid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    foreach ($id in $ids) {
        assert ($id -cmatch '^[a-z][a-zA-Z0-9]*$') "Non-camelCase DOM ID: $id in $($file.Name)"
    }
    assert (($ids | Select-Object -Unique).Count -eq $ids.Count) "Duplicate DOM IDs in $($file.Name)"
    foreach ($label in [regex]::Matches($html, '\bfor="([^"]+)"')) {
        assert ($label.Groups[1].Value -cin $ids) "Unresolved label in $($file.Name): $($label.Groups[1].Value)"
    }
}
foreach ($file in Get-ChildItem $root -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') }) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    assert (-not $parseErrors.Count) "Parse errors in $($file.Name): $parseErrors"
    foreach ($node in $ast.FindAll({
        param($item)
        $item -is [System.Management.Automation.Language.FunctionDefinitionAst] -or
        $item -is [System.Management.Automation.Language.TypeDefinitionAst]
    }, $true)) {
        if ($file.Directory.Name -eq 'tests' -and $node.Name -match '^(Get|New|Write)-(Mg|Pode)') { continue }
        assert ($node.Name -cmatch '^[a-z][a-zA-Z0-9]*$') "Non-camelCase declaration: $($node.Name)"
    }
    foreach ($node in $ast.FindAll({ param($item) $item -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
        $name = $node.VariablePath.UserPath -replace '^(script|local|global|private|using):', ''
        if ($name -in $automaticVariables -or $name -in @('_', 'true', 'false', 'null')) { continue }
        assert ($name -cmatch '^[a-z][a-zA-Z0-9]*$') "Non-camelCase variable: $name in $($file.Name)"
    }
}

foreach ($module in Get-ChildItem (Join-Path $root 'functions') -Filter '*.psm1' | Sort-Object { $_.Name -ne 'writeLog.psm1' }) {
    Import-Module $module.FullName -DisableNameChecking
}
foreach ($name in @('initializeLog', 'writeLog', 'fetchData', 'getRoleMapping', 'displayMainMenu', 'testRequirements', 'installPrerequisites', 'invokeGdapRelationshipRequest')) {
    assert ($null -ne (Get-Command $name -ErrorAction SilentlyContinue)) "Missing renamed export: $name"
}

$serverAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'server.ps1'), [ref]$null, [ref]$null)
$portAssignment = $serverAst.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -eq '$portCheck'
}
$portGuard = $serverAst.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.TryStatementAst]
}
assert ($null -ne $portAssignment -and $null -ne $portGuard) 'Startup must check the port before Pode starts'
$reservation = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$reservation.Start()
$reservedPort = $reservation.LocalEndpoint.Port
$guardScript = [scriptblock]::Create(
    $portAssignment.Extent.Text.Replace('8080', [string]$reservedPort) + "`n" + $portGuard.Extent.Text)
initializeLog -level Error
try {
    $conflict = $null
    try { & $guardScript } catch { $conflict = $_ }
    assert ($null -ne $conflict) 'An occupied port must fail before loading Pode'
    assert ($conflict.Exception -is [System.InvalidOperationException]) 'Port conflicts must provide a clear startup error'
    assert ($conflict.Exception.Message -match 'bereits belegt.*Strg\+C') 'Port conflict must explain how to stop the existing server'
    assert ($reservation.Server.IsBound) 'The existing listener must not be stopped'
}
finally {
    $reservation.Stop()
}
& $guardScript
$probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $reservedPort)
try {
    $probe.Start()
    assert $probe.Server.IsBound 'Successful preflight must release the port for Pode'
}
finally {
    $probe.Stop()
}

function Get-MgTenantRelationshipDelegatedAdminCustomer([switch]$all, $errorAction) {
    assert $all.IsPresent 'Customer reads must retrieve all pages'
    if ($script:emptyData) { return }
    [pscustomobject]@{ Id = 'customer-1'; DisplayName = 'Contoso'; TenantId = '11111111-1111-1111-1111-111111111111' }
}
function Get-MgTenantRelationshipDelegatedAdminRelationship([switch]$all, $errorAction) {
    assert $all.IsPresent 'Relationship reads must retrieve all pages'
    if ($script:emptyData) { return }
    $activeRelationship = [pscustomobject]@{
        Id = 'relationship-1'
        DisplayName = 'Contoso support'
        Customer = @{ Id = 'customer-1'; DisplayName = 'Contoso'; TenantId = '11111111-1111-1111-1111-111111111111' }
        AccessDetails = @{ UnifiedRoles = @(@{ RoleDefinitionId = '729827e3-9c14-49f7-bb1b-9608f156bbb8' }) }
        Status = 'active'
        AutoExtendDuration = [TimeSpan]::FromDays(180)
        CreatedDateTime = [datetime]'2026-01-01'
        EndDateTime = $null
    }
    $inactiveRelationship = [pscustomobject]@{
        Id = 'relationship-2'
        DisplayName = 'Fabrikam support'
        Customer = @{ DisplayName = 'Fabrikam'; TenantId = '22222222-2222-2222-2222-222222222222' }
        AccessDetails = @{ UnifiedRoles = @() }
        Status = 'terminated'
        AutoExtendDuration = [TimeSpan]::Zero
        CreatedDateTime = [datetime]'2025-01-01'
        EndDateTime = [datetime]'2025-12-31'
    }
    return @($activeRelationship, $inactiveRelationship)
}
function Get-MgRoleManagementDirectoryRoleDefinition([switch]$all, $errorAction) {
    assert $all.IsPresent 'Role mapping must retrieve all pages'
    [pscustomobject]@{ Id = 'role-1'; TemplateId = '729827e3-9c14-49f7-bb1b-9608f156bbb8'; DisplayName = 'Helpdesk Administrator' }
}

$testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('gdapToolkitTests' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($testDirectory)
try {
    initializeLog -level Error -logDirectory $testDirectory
    $data = fetchData
    assert ($data.customers[0].GetType().Name -ceq 'gdapCustomer') 'Customer class must use camelCase'
    assert ($data.relationships[0].GetType().Name -ceq 'gdapRelationship') 'Relationship class must use camelCase'
    $role = $data.relationships[0].relationshipRoles[0]
    assert ($role.roleDisplayName -eq 'Helpdesk Administrator') 'Role mapping must survive the rename'
    assert (($role.PSObject.Properties.Name -join ',') -ceq 'roleDefinitionId,roleDisplayName') 'Serialized roles must use camelCase'
    assert ($data.customers[0].customerGdapRelationships.Count -eq 1) 'Customer relationships must remain linked'
    assert ($data.customers.Count -eq 2) 'Customers with only inactive relationships must be included'
    assert ($data.customers[1].customerTenantId -eq '22222222-2222-2222-2222-222222222222') 'Relationship-only customer tenant must be preserved'
    assert ($data.customers[1].customerGdapRelationships[0].relationshipStatus -eq 'terminated') 'Inactive relationship must remain linked to its customer'
    assert ($null -eq $data.relationships[0].relationshipExpirationDate) 'Nullable dates must be preserved'
    assert ($data.relationships[0].relationshipAutoExtend) 'Auto-extension mapping must be preserved'
    $script:emptyData = $true
    $empty = fetchData | ConvertTo-Json -Compress
    assert ($empty -match '"customers":\[\]' -and $empty -match '"relationships":\[\]') 'Empty data must serialize as arrays'

    $logPath = Join-Path $testDirectory ('gdapToolkit_{0:yyyy-MM-dd}.log' -f (Get-Date))
    writeLog -level Debug -component 'test' -message "first`nsecond"
    $content = Get-Content $logPath -Raw
    assert ($content -match '\[DEBUG  \] \[test\] first second') 'Debug logs must reach the file and remain single-line'
    assert ($content -match '\[fetchData\] Mapping abgeschlossen') 'Imported modules must share the logger configuration'

    $loggerPath = Join-Path $root 'functions/writeLog.psm1'
    1..16 | ForEach-Object -Parallel {
        Import-Module $using:loggerPath
        initializeLog -level Error -logDirectory $using:testDirectory
        writeLog -level Debug -component 'parallelTest' -message "entry $_"
    } -ThrottleLimit 4
    $parallelLines = @(Get-Content $logPath | Where-Object { $_ -match '\[parallelTest\]' })
    assert ($parallelLines.Count -eq 16) 'Concurrent writes must preserve every log entry'
    $before = [System.IO.File]::ReadAllText($logPath)
    initializeLog -level Error
    writeLog -level Debug -component 'test' -message 'file disabled'
    assert ([System.IO.File]::ReadAllText($logPath) -ceq $before) 'Disabling file logging must stop file writes'
}
finally {
    initializeLog -level Error
    foreach ($file in Get-ChildItem $testDirectory -File) { Remove-Item -LiteralPath $file.FullName }
    Remove-Item -LiteralPath $testDirectory
}
'Toolkit tests passed (naming, parsing, imports, mocked data and concurrent logging).'
