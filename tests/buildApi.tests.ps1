$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $root 'server.ps1'), [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$modulePath = Join-Path $root 'functions/invokeGdapRelationshipRequest.psm1'
[void][System.Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
Import-Module $modulePath -Force
Import-Module (Join-Path $root 'functions/writeLog.psm1')
initializeLog -level Error

function assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}
function getRoute([string]$path) {
    $command = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Add-PodeRoute' -and
        @($node.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $_.Value -eq $path }).Count -gt 0
    }.GetNewClosure(), $true)
    ($command.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }).ScriptBlock.GetScriptBlock()
}
function Get-PodeHeader($name) { $script:headers[$name] }
function Write-PodeJsonResponse($value, $statusCode = 200, $depth) {
    $script:response = @{ statusCode = $statusCode; body = $value }
}
function Write-PodeErrorLog {
    param([Parameter(ValueFromPipeline)]$errorRecord)
    process { $script:loggedErrors++ }
}
function New-MgTenantRelationshipDelegatedAdminRelationship($bodyParameter, $errorAction) {
    $script:createCalls++
    $script:createdBody = $bodyParameter
    if ($script:failCreate) { throw 'Create failed' }
    [pscustomobject]@{
        Id = 'relationship-123'
        DisplayName = $bodyParameter.displayName
        Status = 'created'
        Duration = [TimeSpan]::FromDays(730)
    }
}
function New-MgTenantRelationshipDelegatedAdminRelationshipRequest($delegatedAdminRelationshipId, $bodyParameter, $errorAction) {
    $script:approvalCalls++
    assert ($delegatedAdminRelationshipId -eq 'relationship-123') 'Approval must use the created ID'
    assert ($bodyParameter.action -eq 'lockForApproval') 'Approval action must be lockForApproval'
    if ($script:failApproval) { throw 'Approval failed' }
    [pscustomobject]@{ Id = 'request-123' }
}
function Get-MgTenantRelationshipDelegatedAdminCustomer([switch]$all, $errorAction) {
    assert $all.IsPresent 'Customer suggestions must include all pages'
    if ($script:failCustomers) { throw 'customers failed' }
    if ($script:emptyCustomers) { return }
    [pscustomobject]@{ DisplayName = 'Zulu'; TenantId = '22222222-2222-2222-2222-222222222222' }
    [pscustomobject]@{ DisplayName = 'Alpha'; TenantId = '11111111-1111-1111-1111-111111111111' }
}

$script:headers = @{ 'Content-Type' = 'application/json'; Origin = 'http://localhost:8080' }
$script:createCalls = 0
$script:approvalCalls = 0
$script:loggedErrors = 0
$body = @{
    displayName = ' Contoso '
    customerTenantId = '11111111-1111-1111-1111-111111111111'
    unifiedRoles = @(@{ roleDefinitionId = '729827e3-9c14-49f7-bb1b-9608f156bbb8' })
}
$WebEvent = @{ Data = $body }
$post = getRoute '/api/relationship'
& $post
assert ($response.statusCode -eq 201) 'Valid request should return 201'
assert ($response.body.status -eq 'approvalRequested' -and $response.body.approvalSubmitted) 'Success must confirm approval submission'
assert ($response.body.result.id -eq 'relationship-123') 'Response must contain the relationship, not the approval request'
assert ($createCalls -eq 1 -and $approvalCalls -eq 1) 'Both Graph steps must run exactly once'
assert ($createdBody.displayName -eq 'Contoso') 'Relationship name must be trimmed'
assert ($createdBody.customer.tenantId -eq $body.customerTenantId) 'Tenant ID must be forwarded'
assert ($createdBody.accessDetails.unifiedRoles.Count -eq 1) 'Selected roles must be forwarded'
assert ($createdBody.duration -eq 'P730D' -and $createdBody.autoExtendDuration -eq 'P180D') 'Defaults must be preserved'

$script:failApproval = $true
& $post
assert ($response.statusCode -eq 502) 'Approval failure must return an error'
assert ($response.body.relationshipCreated -and -not $response.body.approvalSubmitted) 'Partial failure must identify the completed step'
assert ($response.body.result.id -eq 'relationship-123') 'Partial failure must preserve the created ID'
assert ($loggedErrors -eq 1) 'Upstream errors must be logged'
$script:failApproval = $false

$script:failCreate = $true
$before = $approvalCalls
& $post
assert ($response.statusCode -eq 502 -and -not $response.body.relationshipCreated) 'Creation failure must not imply a relationship was created'
assert ($approvalCalls -eq $before) 'Failed creation must not submit an approval'
$script:failCreate = $false

$before = $createCalls
$body.customerTenantId = 'not-a-guid'
& $post
assert ($response.statusCode -eq 400) 'Invalid tenant must return 400'
$body.customerTenantId = '11111111-1111-1111-1111-111111111111'
$body.unifiedRoles = @()
& $post
assert ($response.statusCode -eq 400) 'Empty roles must return 400'
$body.unifiedRoles = @(@{ roleDefinitionId = '62e90394-69f5-4237-9190-012177145e10' })
& $post
assert ($response.statusCode -eq 400) 'Global Administrator with auto-extension must be rejected'
assert ($createCalls -eq $before) 'Invalid requests must not create relationships'
$body.autoExtendDuration = 'PT0S'
& $post
assert ($response.statusCode -eq 201) 'Global Administrator without auto-extension should be allowed'

$script:headers.Origin = 'http://example.invalid'
& $post
assert ($response.statusCode -eq 403) 'Foreign origin must be rejected'
$script:headers.Origin = 'http://localhost:8080'
$script:headers['Content-Type'] = 'text/plain'
& $post
assert ($response.statusCode -eq 415) 'Non-JSON request must be rejected'

$customers = getRoute '/api/customers'
& $customers
assert ($response.statusCode -eq 200 -and $response.body.customers.Count -eq 2) 'Customer endpoint must return a list'
assert ($response.body.customers[0].displayName -eq 'Alpha') 'customers must be sorted'
$script:emptyCustomers = $true
& $customers
assert (($response.body | ConvertTo-Json -Compress) -eq '{"customers":[]}') 'Empty customers must serialize as an array'
$script:failCustomers = $true
& $customers
assert ($response.statusCode -eq 502 -and $response.body.error -eq 'customers failed') 'Customer errors must be explicit'
'Build API tests passed (mocked Graph; no live writes).'
