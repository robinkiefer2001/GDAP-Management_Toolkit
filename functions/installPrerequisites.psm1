##  Prerequisite-Installation für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command writeLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'writeLog.psm1') -DisableNameChecking
}

function installPrerequisites {
    <#
    .SYNOPSIS
        Installiert ein benötigtes PowerShell-Modul im CurrentUser-Scope.
    .PARAMETER moduleName
        Name des zu installierenden Moduls (PowerShell Gallery).
    .EXAMPLE
        installPrerequisites -moduleName Pode
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$moduleName
    )

    writeLog -component 'installPrerequisites' -message "Installiere benötigtes Modul '$moduleName' …"
    try {
        Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        writeLog -component 'installPrerequisites' -message "Modul '$moduleName' erfolgreich installiert."
    }
    catch {
        writeLog -level Error -component 'installPrerequisites' -message "Installation von '$moduleName' fehlgeschlagen: $($_.Exception.Message)"
        throw "Failed to install required module '$moduleName': $_"
    }
}

Export-ModuleMember -Function installPrerequisites
