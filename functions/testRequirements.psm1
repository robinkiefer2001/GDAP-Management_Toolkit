##  Requirement Checks für das GDAP Management Toolkit

if (-not (Get-Command installPrerequisites -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'installPrerequisites.psm1') -DisableNameChecking
}

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command writeLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'writeLog.psm1') -DisableNameChecking
}

function testRequirements {
    <#
    .SYNOPSIS
        Prüft die in requirements.json definierten Voraussetzungen.
    .DESCRIPTION
        Parst die übergebene Requirements-JSON und prüft jede Anforderung.
        Fehlende PowerShell-Module werden automatisch über
        installPrerequisites nachinstalliert.
    .PARAMETER requirements
        Inhalt der requirements.json als Roh-String.
    .EXAMPLE
        testRequirements -requirements (Get-Content .\config\requirements.json -Raw)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$requirements
    )

    $parsed = ($requirements | ConvertFrom-Json).requirements
    writeLog -level Verbose -component 'testRequirements' -message "Prüfe $(@($parsed).Count) Voraussetzungen …"

    foreach ($requirement in $parsed) {
        writeLog -level Debug -component 'testRequirements' -message "Prüfe Voraussetzung: $($requirement.name) / $($requirement.module)"

        if ($requirement.name -eq 'Module') {
            if (-not (Get-Module -ListAvailable -Name $requirement.module)) {
                writeLog -level Warning -component 'testRequirements' -message "Benötigtes Modul '$($requirement.module)' ist nicht installiert."
                installPrerequisites -moduleName $requirement.module
            }
            else {
                writeLog -level Verbose -component 'testRequirements' -message "Modul '$($requirement.module)' ist installiert."
            }
        }
    }

    writeLog -level Verbose -component 'testRequirements' -message 'Alle Voraussetzungen erfüllt.'
}

Export-ModuleMember -Function testRequirements
