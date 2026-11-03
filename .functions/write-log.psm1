##  Zentrales Logging für das GDAP Management Toolkit

$script:LogLevels = @{ Debug = 0; Verbose = 1; Info = 2; Warning = 3; Error = 4 }
$script:LogConfig = @{ Level = 'Info'; FilePath = $null }

function Initialize-Log {
    <#
    .SYNOPSIS
        Initialisiert das zentrale Logging des Toolkits.
    .DESCRIPTION
        Legt das minimale Loglevel für die Konsolenausgabe fest und aktiviert
        optional eine tagesbasierte Logdatei. In die Logdatei werden immer alle
        Meldungen geschrieben (inkl. Debug), die Konsole wird nach Level gefiltert.
    .PARAMETER Level
        Minimales Loglevel für die Konsolenausgabe. Standard: Info.
    .PARAMETER LogDirectory
        Verzeichnis für Logdateien (wird bei Bedarf erstellt). Ohne Angabe wird
        keine Logdatei geschrieben.
    .EXAMPLE
        Initialize-Log -Level Verbose -LogDirectory .\logs
    #>
    [CmdletBinding()]
    param (
        [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [string]$LogDirectory
    )

    $script:LogConfig.Level = $Level

    if ($LogDirectory) {
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }
        $script:LogConfig.FilePath = Join-Path $LogDirectory ('gdap-toolkit_{0:yyyy-MM-dd}.log' -f (Get-Date))
    }
    else {
        $script:LogConfig.FilePath = $null
    }

    $fileInfo = if ($script:LogConfig.FilePath) { $script:LogConfig.FilePath } else { 'deaktiviert' }
    Write-Log -Level Debug -Component 'Log' -Message "Logging initialisiert (Level: $Level, Datei: $fileInfo)"
}

function Write-Log {
    <#
    .SYNOPSIS
        Schreibt eine Logmeldung auf Konsole und (falls aktiviert) in die Logdatei.
    .DESCRIPTION
        Einheitliches Logformat: [Zeitstempel] [LEVEL] [Komponente] Meldung.
        Die Konsolenausgabe wird über das in Initialize-Log konfigurierte
        Loglevel gefiltert, die Logdatei erhält immer alle Meldungen.
    .PARAMETER Message
        Der Text der Logmeldung.
    .PARAMETER Level
        Schweregrad der Meldung (Debug, Verbose, Info, Warning, Error). Standard: Info.
    .PARAMETER Component
        Name der Komponente, aus der die Meldung stammt (z.B. 'FetchData'). Standard: Toolkit.
    .EXAMPLE
        Write-Log -Level Verbose -Component 'FetchData' -Message 'Rufe Daten ab …'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [string]$Component = 'Toolkit'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$timestamp] [$($Level.ToUpper().PadRight(7))] [$Component] $Message"

    if ($script:LogConfig.FilePath) {
        try {
            Add-Content -Path $script:LogConfig.FilePath -Value $line -Encoding UTF8
        }
        catch {
            Write-Warning "Logdatei konnte nicht geschrieben werden: $($_.Exception.Message)"
        }
    }

    if ($script:LogLevels[$Level] -lt $script:LogLevels[$script:LogConfig.Level]) {
        return
    }

    $color = switch ($Level) {
        'Debug'   { 'DarkGray' }
        'Verbose' { 'Cyan' }
        'Info'    { 'Gray' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    Write-Host $line -ForegroundColor $color
}

Export-ModuleMember -Function Initialize-Log, Write-Log
