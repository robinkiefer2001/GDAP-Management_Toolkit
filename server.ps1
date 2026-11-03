Import-Module Pode

Start-PodeServer -RootPath $PSScriptRoot {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # fetch-data (inkl. Klassen) in die Pode-Runspaces laden
    Import-PodeModule -Path './.functions/fetch-data.psm1'

    # Demo-Endpunkt – hier später deine Funktionen aufrufen
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
            Write-PodeJsonResponse -StatusCode 500 -Value @{ error = $_.Exception.Message }
        }
    }

    # Statische Website aus .\public ausliefern (http://localhost:8080/)
    Add-PodeStaticRoute -Path '/' -Source './public' -Defaults @('index.html')
}