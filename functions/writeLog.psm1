##  Zentrales Logging für das GDAP Management Toolkit

$script:logLevels = @{ Debug = 0; Verbose = 1; Info = 2; Warning = 3; Error = 4 }
$script:logConfig = @{ level = 'Info'; logDirectory = $null }

function initializeLog {
    <#
    .SYNOPSIS
        Initialisiert das zentrale Logging des Toolkits.
    .DESCRIPTION
        Legt das minimale Loglevel für die Konsolenausgabe fest und aktiviert
        optional eine tagesbasierte Logdatei. In die Logdatei werden immer alle
        Meldungen geschrieben (inkl. Debug), die Konsole wird nach Level gefiltert.
    .PARAMETER level
        Minimales Loglevel für die Konsolenausgabe. Standard: Info.
    .PARAMETER logDirectory
        Verzeichnis für Logdateien (wird bei Bedarf erstellt). Ohne Angabe wird
        keine Logdatei geschrieben.
    .EXAMPLE
        initializeLog -level Verbose -logDirectory .\logs
    #>
    [CmdletBinding()]
    param (
        [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
        [string]$level = 'Info',

        [string]$logDirectory
    )

    if ($logDirectory) {
        $logDirectory = [System.IO.Path]::GetFullPath($logDirectory)
        [void][System.IO.Directory]::CreateDirectory($logDirectory)
    }
    $script:logConfig = @{ level = $level; logDirectory = $logDirectory }
}

function writeLog {
    <#
    .SYNOPSIS
        Schreibt eine Logmeldung auf Konsole und (falls aktiviert) in die Logdatei.
    .DESCRIPTION
        Einheitliches Logformat: [Zeitstempel] [LEVEL] [Komponente] Meldung.
        Die Konsolenausgabe wird über das in initializeLog konfigurierte
        Loglevel gefiltert, die Logdatei erhält immer alle Meldungen.
    .PARAMETER message
        Der Text der Logmeldung.
    .PARAMETER level
        Schweregrad der Meldung (Debug, Verbose, Info, Warning, Error). Standard: Info.
    .PARAMETER component
        Name der Komponente, aus der die Meldung stammt (z.B. 'fetchData'). Standard: toolkit.
    .EXAMPLE
        writeLog -level Verbose -component 'fetchData' -message 'Rufe Daten ab …'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$message,

        [ValidateSet('Debug', 'Verbose', 'Info', 'Warning', 'Error')]
        [string]$level = 'Info',

        [string]$component = 'toolkit'
    )

    $now = Get-Date
    $timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss.fff')
    $message = $message -replace '[\r\n]+', ' '
    $component = $component -replace '[\r\n]+', ' '
    $line = "[$timestamp] [$($level.ToUpperInvariant().PadRight(7))] [$component] $message"

    if ($script:logConfig.logDirectory) {
        $filePath = Join-Path $script:logConfig.logDirectory ('gdapToolkit_{0:yyyy-MM-dd}.log' -f $now)
        $hash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($filePath)))
        $mutex = [System.Threading.Mutex]::new($false, "gdapToolkitLog_$hash")
        $acquired = $false
        try {
            try {
                $acquired = $mutex.WaitOne(5000)
            }
            catch [System.Threading.AbandonedMutexException] {
                $acquired = $true
            }
            if (-not $acquired) { throw 'Timeout beim Sperren der Logdatei.' }
            [System.IO.File]::AppendAllText($filePath, $line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        }
        catch {
            Write-Warning "Logdatei konnte nicht geschrieben werden: $($_.Exception.Message)"
        }
        finally {
            if ($acquired) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }

    if ($script:logLevels[$level] -lt $script:logLevels[$script:logConfig.level]) {
        return
    }

    $color = switch ($level) {
        'Debug'   { 'DarkGray' }
        'Verbose' { 'Cyan' }
        'Info'    { 'Gray' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    Write-Host $line -ForegroundColor $color
}

Export-ModuleMember -Function initializeLog, writeLog
