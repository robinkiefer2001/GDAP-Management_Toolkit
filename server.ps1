<#
.SYNOPSIS
    GDAP Management Toolkit – Web-Modus (Pode).
.DESCRIPTION
    Startet einen lokalen Pode-Webserver auf http://localhost:8080, liefert die
    Weboberfläche aus .\public aus und stellt die REST-API bereit (siehe docs\API.md).

    Logging:
      - HTTP-Requests werden im Terminal protokolliert.
      - Serverfehler werden zusätzlich nach .\logs geschrieben.

    Voraussetzung: aktive Microsoft-Graph-Verbindung in derselben Session,
    sonst liefert /api/data den Status 500.
.EXAMPLE
    Connect-MgGraph -Scopes 'DelegatedAdminRelationship.Read.All'
    .\server.ps1
.NOTES
    Autor: robinkiefer2001 – https://github.com/robinkiefer2001/GDAP-Management_Toolkit
#>
[CmdletBinding()]
param ()

Import-Module Pode

Start-PodeServer -RootPath $PSScriptRoot {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Logging: Requests ins Terminal, Fehler zusätzlich nach .\logs
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -File -Name 'error' -Path './logs' | Enable-PodeErrorLogging

    # fetch-data (inkl. Klassen und Logging) in die Pode-Runspaces laden
    Import-PodeModule -Path './.functions/fetch-data.psm1'
    Import-PodeModule -Name Microsoft.Graph.Authentication
    Import-PodeModule -Name Microsoft.Graph.Identity.Partner
    Import-PodeModule -Path './.functions/invoke-gdapRelationshipRequest.psm1'

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
            $data = fetch-data
            Write-PodeJsonResponse -Depth 10 -Value @{
                customers     = @($data.Customers)
                relationships = @($data.Relationships)
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = $_.Exception.Message }
        }
    }

    # Built-in Entra role catalogue; Graph validates GDAP eligibility on creation.
    Add-PodeRoute -Method Get -Path '/api/roles' -ScriptBlock {
        try {
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
            Write-PodeJsonResponse -StatusCode 403 -Value @{ error = 'Origin not allowed.' }
            return
        }
        if ((Get-PodeHeader -Name 'Content-Type') -notmatch '^application/json(?:\s*;|$)') {
            Write-PodeJsonResponse -StatusCode 415 -Value @{ error = 'Use application/json.' }
            return
        }
        try {
            $body = $WebEvent.Data
            if ($null -eq $body -or $body -isnot [System.Collections.IDictionary]) { throw 'JSON object required.' }
            $name = [string]$body.DisplayName
            if ([string]::IsNullOrWhiteSpace($name) -or $name.Trim().Length -gt 50) {
                throw 'DisplayName must contain 1–50 characters.'
            }
            $tenant = [guid]$body.CustomerTenantId
            if ($tenant -eq [guid]::Empty) { throw 'Valid CustomerTenantId required.' }
            $duration = if ($body.Duration) { [string]$body.Duration } else { 'P730D' }
            if ($duration -notmatch '^P([1-9]|[1-9][0-9]|[1-6][0-9]{2}|7[01][0-9]|72[0-9]|730)D$') {
                throw 'Duration must be P1D through P730D.'
            }
            $auto = if ($body.AutoExtendDuration) { [string]$body.AutoExtendDuration } else { 'P180D' }
            if ($auto -notin @('P0D','PT0S','P180D')) { throw 'Invalid AutoExtendDuration.' }
            if (-not $body.UnifiedRoles -or $body.UnifiedRoles -isnot [array]) { throw 'Select at least one role.' }
            $roles = @($body.UnifiedRoles | ForEach-Object {
                $id = [guid]$_.roleDefinitionId
                if ($id -eq [guid]::Empty) { throw 'Invalid role ID.' }
                @{ roleDefinitionId = $id.ToString() }
            })
            if ($auto -eq 'P180D' -and $roles.roleDefinitionId -contains '62e90394-69f5-4237-9190-012177145e10') {
                throw 'Disable auto-extension when selecting Global Administrator.'
            }
            $parameters = @{
                DisplayName = $name.Trim()
                CustomerTenantId = $tenant
                Duration = $duration
                AutoExtendDuration = $auto
                UnifiedRoles = $roles
            }
        }
        catch {
            Write-PodeJsonResponse -StatusCode 400 -Value @{ error = $_.Exception.Message }
            return
        }
        try {
            $result = Invoke-GdapRelationshipRequest @parameters -ErrorAction Stop
            Write-PodeJsonResponse -Depth 10 -StatusCode 201 -Value @{
                status = 'created'
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
            Write-PodeJsonResponse -StatusCode $status -Value @{ error = $_.Exception.Message }
        }
    }

    # Statische Website aus .\public ausliefern (http://localhost:8080/)
    Add-PodeStaticRoute -Path '/' -Source './public' -Defaults @('index.html')
}
