##  Prerequisite-Installation für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'write-log.psm1') -DisableNameChecking
}

function Install-Prerequisites {
    <#
    .SYNOPSIS
        Installiert ein benötigtes PowerShell-Modul im CurrentUser-Scope.
    .PARAMETER ModuleName
        Name des zu installierenden Moduls (PowerShell Gallery).
    .EXAMPLE
        Install-Prerequisites -ModuleName Pode
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    Write-Log -Component 'Installer' -Message "Installiere benötigtes Modul '$ModuleName' …"
    try {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Log -Component 'Installer' -Message "Modul '$ModuleName' erfolgreich installiert."
    }
    catch {
        Write-Log -Level Error -Component 'Installer' -Message "Installation von '$ModuleName' fehlgeschlagen: $($_.Exception.Message)"
        throw "Failed to install required module '$ModuleName': $_"
    }
}

Export-ModuleMember -Function Install-Prerequisites
