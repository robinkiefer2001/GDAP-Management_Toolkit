##  Requirement Checks für das GDAP Management Toolkit

Import-Module (Join-Path $PSScriptRoot 'install-prerequisites.psm1') -Force -DisableNameChecking

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'write-log.psm1') -DisableNameChecking
}

function Test-Requirement {
    <#
    .SYNOPSIS
        Prüft die in requirements.json definierten Voraussetzungen.
    .DESCRIPTION
        Parst die übergebene Requirements-JSON und prüft jede Anforderung.
        Fehlende PowerShell-Module werden automatisch über
        Install-Prerequisites nachinstalliert.
    .PARAMETER requirements
        Inhalt der requirements.json als Roh-String.
    .EXAMPLE
        Test-Requirement -requirements (Get-Content .\.static\requirements.json -Raw)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$requirements
    )

    $parsed = ($requirements | ConvertFrom-Json).requirements
    Write-Log -Level Verbose -Component 'Requirements' -Message "Prüfe $(@($parsed).Count) Voraussetzungen …"

    foreach ($requirement in $parsed) {
        Write-Log -Level Debug -Component 'Requirements' -Message "Prüfe Voraussetzung: $($requirement.name) / $($requirement.module)"

        if ($requirement.name -eq 'Module') {
            if (-not (Get-Module -ListAvailable -Name $requirement.module)) {
                Write-Log -Level Warning -Component 'Requirements' -Message "Benötigtes Modul '$($requirement.module)' ist nicht installiert."
                Install-Prerequisites -ModuleName $requirement.module
            }
            else {
                Write-Log -Level Verbose -Component 'Requirements' -Message "Modul '$($requirement.module)' ist installiert."
            }
        }
    }

    Write-Log -Level Verbose -Component 'Requirements' -Message 'Alle Voraussetzungen erfüllt.'
}

Export-ModuleMember -Function Test-Requirement
