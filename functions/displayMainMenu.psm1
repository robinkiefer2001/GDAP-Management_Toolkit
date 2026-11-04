##  Hauptmenü für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command writeLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'writeLog.psm1') -DisableNameChecking
}

function displayMainMenu {
    <#
    .SYNOPSIS
        Zeigt das Hauptmenü an und gibt die Auswahl des Benutzers zurück.
    .OUTPUTS
        string – die gewählte Menüoption.
    .EXAMPLE
        $selection = displayMainMenu
    #>
    [CmdletBinding()]
    param ()

    Write-Host ''
    Write-Host '=== GDAP Management Toolkit – Hauptmenü ===' -ForegroundColor Yellow
    Write-Host '1. Use GDAP Management Toolkit | Console Mode'
    Write-Host '2. Get GDAP customers'
    Write-Host '3. Get GDAP relationships'
    Write-Host '4. Web Mode'

    $selection = Read-Host -Prompt 'Please select an option from the menu'
    writeLog -level Verbose -component 'displayMainMenu' -message "Benutzerauswahl: '$selection'"

    switch ($selection) {
        '1' { Write-Host 'You selected: Use GDAP Management Toolkit | Console Mode' -ForegroundColor Green }
        '2' { Write-Host 'You selected: Get GDAP customers' -ForegroundColor Green }
        '3' { Write-Host 'You selected: Get GDAP relationships' -ForegroundColor Green }
        '4' { Write-Host 'You selected: Web Mode' -ForegroundColor Green }
        default {
            writeLog -level Warning -component 'displayMainMenu' -message "Ungültige Auswahl: '$selection'"
        }
    }

    return $selection
}

Export-ModuleMember -Function displayMainMenu
