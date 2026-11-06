function initialiseConfig {
    [CmdletBinding()]
    param (
        [string]$TemplatePath = '',
        [string]$DataPath = '',
        [string]$AuthMethod = 'Interactive',
        [string]$TempPath = '',
        [string]$LogLevel = 'verbose',
        [string]$OutputFormat = ''
    )

    $configPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\settings.json'

    writeLog -component 'initialiseConfig' -message 'Initialisiere Konfiguration …'

    # Hier kann die Initialisierung der Konfiguration erfolgen
    $config = @{
        logLevel = $LogLevel  # Beispielhafte Konfiguration für das Log-Level
        outputFormat = $OutputFormat  # Beispielhafte Konfiguration für das Ausgabeformat
        authMethod = $AuthMethod  # Beispielhafte Konfiguration für die Authentifizierungsmethode
        TemplatePath = $TemplatePath  # Beispielhafte Konfiguration für den Pfad zu Templates
        DataPath = $DataPath  # Beispielhafte Konfiguration für den Pfad zu Daten
        TempPath = $TempPath  # Beispielhafte Konfiguration für den Pfad zu temporären Dateien
    }

    # Setup Configuration
    if (Test-Path $configPath) {
        writeLog -component 'initialiseConfig' -message 'Konfigurationsdatei existiert bereits.'
    }
    if (-not (Test-Path $configPath)) {
        new-item -path $configPath -itemtype file -force
        set-content -path $configPath -value ($config | convertto-json)
        writeLog -component 'initialiseConfig' -message 'Konfigurationsdatei wurde erstellt.'
    }

    writeLog -component 'initialiseConfig' -message 'Konfiguration initialisiert.'
}

Export-ModuleMember -Function initialiseConfig