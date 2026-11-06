<#
.SYNOPSIS
    GDAP Management Toolkit – Konsolenmodus.
.DESCRIPTION
    Prüft die Voraussetzungen (und installiert fehlende Module automatisch),
    verbindet sich mit Microsoft Graph, lädt alle GDAP-Kunden und -Beziehungen
    und zeigt das interaktive Hauptmenü an.
.PARAMETER logLevel
    Minimales Loglevel für die Konsolenausgabe:
    Debug, Verbose, Info (Standard), Warning oder Error.
    In die Logdatei unter .\logs wird unabhängig davon immer alles geschrieben.
.PARAMETER noFileLog
    Deaktiviert das Schreiben der Logdatei unter .\logs.
.EXAMPLE
    .\gdapToolkit.ps1
.EXAMPLE
    .\gdapToolkit.ps1 -logLevel Verbose
.EXAMPLE
    .\gdapToolkit.ps1 -Debug -noFileLog
.NOTES
    Autor: robinkiefer2001 – https://github.com/robinkiefer2001/GDAP-Management_Toolkit
#>
[CmdletBinding()]
param (
    [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
    [string]$logLevel = 'Info',

    [switch]$noFileLog
)

# $PSScriptRoot ist leer, wenn Zeilen interaktiv ausgeführt werden – Fallback auf das aktuelle Verzeichnis
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# Common Parameters -Verbose/-Debug auf das Loglevel abbilden
if ($PSBoundParameters.ContainsKey('Debug')) { $logLevel = 'Debug' }
elseif ($PSBoundParameters.ContainsKey('Verbose')) { $logLevel = 'Verbose' }

# Funktionsmodule laden – writeLog zuerst, damit alle Module dieselbe Logging-Instanz nutzen
$functionModules = Get-ChildItem -Path (Join-Path $scriptRoot 'functions') -Filter '*.psm1' |
    Sort-Object { $_.Name -ne 'writeLog.psm1' }
foreach ($module in $functionModules) {
    Import-Module $module.FullName -Force -DisableNameChecking
}

if ($noFileLog) {
    initializeLog -level $logLevel
}
else {
    initializeLog -level $logLevel -logDirectory (Join-Path $scriptRoot 'logs')
}

try {
    initialiseConfig
}
catch {
    writeLog -level Error -component 'gdapToolkit' -message "Fehler bei der Initialisierung der Konfiguration: $($_.Exception.Message)"
    throw
}

writeLog -component 'gdapToolkit' -message 'GDAP Management Toolkit gestartet.'

try {
    $requirementsJson = Get-Content (Join-Path $scriptRoot 'config/requirements.json') -Raw
    testRequirements -requirements $requirementsJson

    writeLog -component 'gdapToolkit' -message 'Verbinde mit Microsoft Graph …'
    # Browser-Login statt WAM erzwingen – zuverlässiger in eingebetteten Terminals (z.B. VS Code)
    # (Graph SDK < 2.40: -EnableLoginByWAM $false)
    Set-MgGraphOption -DisableLoginByWAM $true
    Connect-MgGraph -Scopes 'User.Read.All', 'Directory.Read.All', 'DelegatedAdminRelationship.Read.All' -ErrorAction Stop | Out-Null
    writeLog -component 'gdapToolkit' -message 'Microsoft-Graph-Verbindung hergestellt.'

    $data = fetchData
    writeLog -component 'gdapToolkit' -message "Daten geladen: $($data.customers.Count) Kunden, $($data.relationships.Count) Beziehungen."

    $menuSelection = displayMainMenu

    switch ($menuSelection) {
        '1' { writeLog -component 'gdapToolkit' -message 'Konsolenmodus ist noch nicht implementiert.' }
        '2' { $data.customers }
        '3' { $data.relationships }
        '4' {
            writeLog -component 'main' -message 'Starte Web-Modus.'
            & (Join-Path $scriptRoot 'server.ps1') -logLevel $logLevel -noFileLog:$noFileLog
        }
    }

    writeLog -component 'gdapToolkit' -message 'GDAP Management Toolkit beendet.'
}
catch {
    writeLog -level Error -component 'gdapToolkit' -message "Abbruch: $($_.Exception.Message)"
    throw
}
