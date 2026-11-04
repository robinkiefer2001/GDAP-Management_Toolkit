<#
.SYNOPSIS
    GDAP Management Toolkit – Web-Modus (Pode).
.DESCRIPTION
    Startet einen lokalen Pode-Webserver auf http://localhost:8080, liefert die
    Weboberfläche aus .\public aus und stellt die REST-API bereit (siehe docs/api.md).

    Einheitliches Logging für HTTP-Requests, Datenabrufe, Erstellung und Fehler.
    Tagesbasierte Logdateien unter .\logs; Konsole nach logLevel gefiltert.

    Voraussetzung: aktive Microsoft-Graph-Verbindung in derselben Session,
    sonst liefert /api/data den Status 500.
.EXAMPLE
    Connect-MgGraph -Scopes 'DelegatedAdminRelationship.ReadWrite.All', 'Directory.Read.All'
    .\server.ps1
.PARAMETER logLevel
    Minimales Loglevel der Konsole; Logdateien enthalten alle Level.
.PARAMETER noFileLog
    Deaktiviert Logdateien auch in den Pode-Runspaces.
.NOTES
    Autor: robinkiefer2001 – https://github.com/robinkiefer2001/GDAP-Management_Toolkit
#>
[CmdletBinding()]
param (
    [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
    [string]$logLevel = 'Info',
    [switch]$noFileLog
)

Import-Module (Join-Path $PSScriptRoot 'functions/writeLog.psm1') -DisableNameChecking
if ($PSBoundParameters.ContainsKey('Debug')) { $logLevel = 'Debug' }
elseif ($PSBoundParameters.ContainsKey('Verbose')) { $logLevel = 'Verbose' }
$logSettings = @{ level = $logLevel }
if (-not $noFileLog) { $logSettings.logDirectory = Join-Path $PSScriptRoot 'logs' }
initializeLog @logSettings

$portCheck = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 8080)
try {
    $portCheck.Start()
}
catch [System.Net.Sockets.SocketException] {
    $message = if ($_.Exception.SocketErrorCode -eq [System.Net.Sockets.SocketError]::AddressAlreadyInUse) {
        'Port 8080 ist bereits belegt. Den laufenden Server zuerst in seiner PowerShell-/VS-Code-Konsole mit Strg+C stoppen und danach server.ps1 erneut starten. Keine weitere Serverinstanz starten.'
    }
    else {
        "Port 8080 konnte nicht geöffnet werden: $($_.Exception.Message)"
    }
    writeLog -level Error -component 'server' -message $message
    throw [System.InvalidOperationException]::new($message, $_.Exception)
}
finally {
    $portCheck.Stop()
}

Import-Module Pode -ErrorAction Stop
writeLog -component 'server' -message 'Starte Web-Modus auf http://localhost:8080.'

Start-PodeServer -RootPath $PSScriptRoot -ScriptBlock ({
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Set-PodeState -Name 'logSettings' -Value $logSettings -NoPassThru
    Import-PodeModule -Path './functions/writeLog.psm1'
    Add-PodeMiddleware -Name 'initializeLogging' -ScriptBlock {
        $settings = Get-PodeState -Name 'logSettings'
        initializeLog @settings
        return $true
    }
    New-PodeLogCustomMethod -ScriptBlock {
        param($items)
        $settings = Get-PodeState -Name 'logSettings'
        initializeLog @settings
        foreach ($item in $items) {
            writeLog -component 'http' -message ([string]$item)
        }
    } | Enable-PodeRequestLogging -ScriptBlock {
        param($logEvent)
        "$($logEvent.Data.Request.Method) $($logEvent.Data.Request.Resource) -> $($logEvent.Data.Response.StatusCode)"
    } -SerialiseFormat Custom -SerialiseScriptBlock { param($data) [string]$data }
    New-PodeLogCustomMethod -ScriptBlock {
        param($items)
        $settings = Get-PodeState -Name 'logSettings'
        initializeLog @settings
        foreach ($item in $items) {
            writeLog -level Error -component 'server' -message ([string]$item)
        }
    } | Enable-PodeErrorLogging -ScriptBlock {
        param($logEvent)
        $logEvent.Data.Message
    } -SerialiseFormat Custom -SerialiseScriptBlock { param($data) [string]$data }

    # fetchData (inkl. Klassen und Logging) in die Pode-Runspaces laden
    Import-PodeModule -Path './functions/fetchData.psm1'
    Import-PodeModule -Name Microsoft.Graph.Authentication
    Import-PodeModule -Name Microsoft.Graph.Identity.Partner
    Import-PodeModule -Path './functions/invokeGdapRelationshipRequest.psm1'

    # Healthcheck
    Add-PodeRoute -Method Get -Path '/api/status' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            status  = 'ok'
            message = 'PowerShell-Backend erreichbar'
        }
    }

    # Kunden + GDAP-Beziehungen als JSON (benötigt aktive Graph-Verbindung)
    Add-PodeRoute -Method Get -Path '/api/data' -ScriptBlock {
        try {
            $data = fetchData
            Write-PodeJsonResponse -Depth 10 -Value @{
                customers     = @($data.customers)
                relationships = @($data.relationships)
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = $_.Exception.Message }
        }
    }

    # Customer suggestions without loading relationships and role mappings.
    Add-PodeRoute -Method Get -Path '/api/customers' -ScriptBlock {
        try {
            writeLog -level Verbose -component 'customersApi' -message 'Lade bekannte Kunden aus Microsoft Graph.'
            $customers = @(Get-MgTenantRelationshipDelegatedAdminCustomer -All -ErrorAction Stop | ForEach-Object {
                @{ displayName = $_.DisplayName; tenantId = $_.TenantId }
            } | Sort-Object { $_.displayName })
            writeLog -component 'customersApi' -message "$($customers.Count) Kunden geladen."
            Write-PodeJsonResponse -Depth 5 -Value @{ customers = $customers }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeJsonResponse -StatusCode 502 -Value @{ error = $_.Exception.Message }
        }
    }

    # Built-in Entra role catalogue; Graph validates GDAP eligibility on creation.
    Add-PodeRoute -Method Get -Path '/api/roles' -ScriptBlock {
        try {
            writeLog -level Verbose -component 'rolesApi' -message 'Lade integrierte Entra-Rollen aus Microsoft Graph.'
            $uri = 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?$filter=isBuiltIn%20eq%20true&$select=id,templateId,displayName,description,isEnabled'
            $roles = @()
            do {
                $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
                $roles += @($page.value | Where-Object { $_.isEnabled -ne $false } | ForEach-Object {
                    @{
                        id = $(if ($_.templateId) { $_.templateId } else { $_.id })
                        displayName = $_.displayName
                        description = $_.description
                    }
                })
                $uri = $page.'@odata.nextLink'
            } while ($uri)
            writeLog -component 'rolesApi' -message "$($roles.Count) Rollen geladen."
            Write-PodeJsonResponse -Depth 5 -Value @{ roles = @($roles | Sort-Object { $_.displayName }) }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeJsonResponse -StatusCode 502 -Value @{ error = $_.Exception.Message }
        }
    }

    Add-PodeRoute -Method Post -Path '/api/relationship' -ScriptBlock {
        # Restrict browser writes to this local origin; JSON is required.
        $origin = Get-PodeHeader -Name 'Origin'
        if ($origin -and $origin -ne 'http://localhost:8080') {
            writeLog -level Warning -component 'relationshipApi' -message 'Erstellung wegen unzulässiger Origin abgelehnt.'
            Write-PodeJsonResponse -StatusCode 403 -Value @{ error = 'Origin not allowed.' }
            return
        }
        if ((Get-PodeHeader -Name 'Content-Type') -notmatch '^application/json(?:\s*;|$)') {
            writeLog -level Warning -component 'relationshipApi' -message 'Erstellung wegen falschem Content-Type abgelehnt.'
            Write-PodeJsonResponse -StatusCode 415 -Value @{ error = 'Use application/json.' }
            return
        }
        try {
            $body = $WebEvent.Data
            if ($null -eq $body -or $body -isnot [System.Collections.IDictionary]) { throw 'JSON object required.' }
            $name = [string]$body.displayName
            if ([string]::IsNullOrWhiteSpace($name) -or $name.Trim().Length -gt 50) {
                throw 'displayName must contain 1–50 characters.'
            }
            $tenant = [guid]$body.customerTenantId
            if ($tenant -eq [guid]::Empty) { throw 'Valid customerTenantId required.' }
            $duration = if ($body.duration) { [string]$body.duration } else { 'P730D' }
            if ($duration -notmatch '^P([1-9]|[1-9][0-9]|[1-6][0-9]{2}|7[01][0-9]|72[0-9]|730)D$') {
                throw 'duration must be P1D through P730D.'
            }
            $auto = if ($body.autoExtendDuration) { [string]$body.autoExtendDuration } else { 'P180D' }
            if ($auto -notin @('P0D','PT0S','P180D')) { throw 'Invalid autoExtendDuration.' }
            if (-not $body.unifiedRoles -or $body.unifiedRoles -isnot [array]) { throw 'Select at least one role.' }
            $roles = @($body.unifiedRoles | ForEach-Object {
                $id = [guid]$_.roleDefinitionId
                if ($id -eq [guid]::Empty) { throw 'Invalid role ID.' }
                @{ roleDefinitionId = $id.ToString() }
            })
            if ($auto -eq 'P180D' -and $roles.roleDefinitionId -contains '62e90394-69f5-4237-9190-012177145e10') {
                throw 'Disable auto-extension when selecting Global Administrator.'
            }
            $parameters = @{
                displayName = $name.Trim()
                customerTenantId = $tenant.ToString()
                duration = $duration
                autoExtendDuration = $auto
                unifiedRoles = $roles
            }
        }
        catch {
            writeLog -level Warning -component 'relationshipApi' -message "Validierung fehlgeschlagen: $($_.Exception.Message)"
            Write-PodeJsonResponse -StatusCode 400 -Value @{ error = $_.Exception.Message }
            return
        }
        try {
            $result = invokeGdapRelationshipRequest @parameters -ErrorAction Stop
            Write-PodeJsonResponse -Depth 10 -StatusCode 201 -Value @{
                status = 'approvalRequested'
                relationshipCreated = $true
                approvalSubmitted = $true
                result = @{
                    id = $result.Id
                    displayName = $result.DisplayName
                    status = $result.Status
                    duration = [string]$result.Duration
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            $status = 502
            $upstream = $_.Exception.ResponseStatusCode
            if (-not $upstream -and $_.Exception.Response) { $upstream = $_.Exception.Response.StatusCode }
            if ($upstream -and [int]$upstream -in @(400,401,403,404,409,429)) { $status = [int]$upstream }
            $errorResponse = @{ error = $_.Exception.Message }
            if ($_.Exception.Data['createdRelationshipId']) {
                $errorResponse.relationshipCreated = $true
                $errorResponse.approvalSubmitted = $false
                $errorResponse.result = @{
                    id = $_.Exception.Data['createdRelationshipId']
                    displayName = $_.Exception.Data['createdRelationshipDisplayName']
                }
            }
            Write-PodeJsonResponse -Depth 5 -StatusCode $status -Value $errorResponse
        }
    }

    # Statische Website aus .\public ausliefern (http://localhost:8080/)
    Add-PodeStaticRoute -Path '/' -Source './public' -Defaults @('index.html')
}.GetNewClosure())
