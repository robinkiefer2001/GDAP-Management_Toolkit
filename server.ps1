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

    # Statische Website aus .\public ausliefern (http://localhost:8080/)
    Add-PodeStaticRoute -Path '/' -Source './public' -Defaults @('index.html')
}
