##  Hauptmenü für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'write-log.psm1') -DisableNameChecking
}

function display-MainMenu {
    <#
    .SYNOPSIS
        Zeigt das Hauptmenü an und gibt die Auswahl des Benutzers zurück.
    .OUTPUTS
        string – die gewählte Menüoption.
    .EXAMPLE
        $selection = display-MainMenu
    #>
    [CmdletBinding()]
    param ()

    Write-Host ''
    Write-Host '=== GDAP Management Toolkit – Hauptmenü ===' -ForegroundColor Yellow
    Write-Host '1. Use GDAP Management Toolkit | Console Mode'
    Write-Host '2. Get GDAP Customers'
    Write-Host '3. Get GDAP Relationships'

    $selection = Read-Host -Prompt 'Please select an option from the menu'
    Write-Log -Level Verbose -Component 'Menu' -Message "Benutzerauswahl: '$selection'"

    switch ($selection) {
        '1' { Write-Host 'You selected: Use GDAP Management Toolkit | Console Mode' -ForegroundColor Green }
        '2' { Write-Host 'You selected: Get GDAP Customers' -ForegroundColor Green }
        '3' { Write-Host 'You selected: Get GDAP Relationships' -ForegroundColor Green }
        default {
            Write-Log -Level Warning -Component 'Menu' -Message "Ungültige Auswahl: '$selection'"
        }
    }

    return $selection
}

Export-ModuleMember -Function display-MainMenu
