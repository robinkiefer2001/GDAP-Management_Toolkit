<#
.SYNOPSIS
    GDAP Management Toolkit – Konsolenmodus.
.DESCRIPTION
    Prüft die Voraussetzungen (und installiert fehlende Module automatisch),
    verbindet sich mit Microsoft Graph, lädt alle GDAP-Kunden und -Beziehungen
    und zeigt das interaktive Hauptmenü an.
.PARAMETER LogLevel
    Minimales Loglevel für die Konsolenausgabe:
    Debug, Verbose, Info (Standard), Warning oder Error.
    In die Logdatei unter .\logs wird unabhängig davon immer alles geschrieben.
.PARAMETER NoFileLog
    Deaktiviert das Schreiben der Logdatei unter .\logs.
.EXAMPLE
    .\gdap-toolkit.ps1
.EXAMPLE
    .\gdap-toolkit.ps1 -LogLevel Verbose
.EXAMPLE
    .\gdap-toolkit.ps1 -Debug -NoFileLog
.NOTES
    Autor: robinkiefer2001 – https://github.com/robinkiefer2001/GDAP-Management_Toolkit
#>
[CmdletBinding()]
param (
    [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
    [string]$LogLevel = 'Info',

    [switch]$NoFileLog
)

# $PSScriptRoot ist leer, wenn Zeilen interaktiv ausgeführt werden – Fallback auf das aktuelle Verzeichnis
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# Common Parameters -Verbose/-Debug auf das Loglevel abbilden
if ($PSBoundParameters.ContainsKey('Debug')) { $LogLevel = 'Debug' }
elseif ($PSBoundParameters.ContainsKey('Verbose')) { $LogLevel = 'Verbose' }

# Funktionsmodule laden – write-log zuerst, damit alle Module dieselbe Logging-Instanz nutzen
$functionModules = Get-ChildItem -Path (Join-Path $scriptRoot '.functions') -Filter '*.psm1' |
    Sort-Object { $_.Name -ne 'write-log.psm1' }
foreach ($module in $functionModules) {
    Import-Module $module.FullName -Force -DisableNameChecking
}

if ($NoFileLog) {
    Initialize-Log -Level $LogLevel
}
else {
    Initialize-Log -Level $LogLevel -LogDirectory (Join-Path $scriptRoot 'logs')
}

Write-Log -Component 'Main' -Message 'GDAP Management Toolkit gestartet.'

try {
    $requirementsJson = Get-Content (Join-Path $scriptRoot '.static\requirements.json') -Raw
    Test-Requirement -requirements $requirementsJson

    Write-Log -Component 'Main' -Message 'Verbinde mit Microsoft Graph …'
    Connect-MgGraph -Scopes 'User.Read.All', 'Directory.Read.All', 'Identity.Governance.Read.All', 'DelegatedAdminRelationship.Read.All' -ErrorAction Stop | Out-Null
    Write-Log -Component 'Main' -Message 'Microsoft-Graph-Verbindung hergestellt.'

    $data = fetch-data
    Write-Log -Component 'Main' -Message "Daten geladen: $($data.Customers.Count) Kunden, $($data.Relationships.Count) Beziehungen."

    $menuSelection = display-MainMenu

    switch ($menuSelection) {
        '1' { Write-Log -Component 'Main' -Message 'Konsolenmodus ist noch nicht implementiert.' }
        '2' { $data.Customers }
        '3' { $data.Relationships }
    }

    Write-Log -Component 'Main' -Message 'GDAP Management Toolkit beendet.'
}
catch {
    Write-Log -Level Error -Component 'Main' -Message "Abbruch: $($_.Exception.Message)"
    throw
}
