# GDAP Management Toolkit

PowerShell-Toolkit für Microsoft-CSP-Partner zur Auswertung und Verwaltung von
**GDAP-Beziehungen** (Granular Delegated Admin Privileges) über Microsoft Graph –
wahlweise im interaktiven **Konsolenmodus** oder als lokale **Weboberfläche**
(Pode-Webserver + daisyUI-Frontend).

## Features

- Abruf aller Delegated-Admin-Kunden und GDAP-Beziehungen des Partner-Tenants
- Typisierte Datenmodelle (`gdapCustomer`, `GdapRelationship`) als PowerShell-Klassen
- Interaktives Konsolenmenü (`gdap-toolkit.ps1`)
- Lokale Web-UI mit Kunden-/Relationship-Drilldown, Suche und Status-Badges (`server.ps1`)
- REST-API für eigene Integrationen (siehe [docs/API.md](docs/API.md))
- Automatische Installation fehlender PowerShell-Module
- Zentrales, konsistentes Logging mit Loglevel-Steuerung und Logdateien

## Projektstruktur

```text
GDAP-Management_Toolkit
├── gdap-toolkit.ps1            # Einstieg: Konsolenmodus
├── server.ps1                  # Einstieg: Web-Modus (Pode, Port 8080)
├── .classes/
│   ├── .customer.psm1          # Klasse gdapCustomer
│   └── .gdapRelationship.psm1  # Klasse GdapRelationship
├── .functions/
│   ├── fetch-data.psm1         # Graph-Abruf + Mapping auf die Klassen
│   ├── display-mainMenu.psm1   # Konsolen-Hauptmenü
│   ├── requirement-checks.psm1 # Prüfung der Voraussetzungen
│   ├── install-prerequisites.psm1  # Nachinstallation fehlender Module
│   └── write-log.psm1          # Zentrales Logging (Initialize-Log, Write-Log)
├── .static/
│   └── requirements.json       # Deklaration der benötigten Module
├── public/                     # Web-Frontend (wird von Pode ausgeliefert)
│   ├── index.html              # Startseite
│   ├── customers.html          # Seite: Customers
│   ├── relationships.html      # Seite: Relationships
│   ├── js/
│   │   ├── layout.js           # Gemeinsames Layout (Navbar + Footer)
│   │   ├── common.js           # Gemeinsame Helfer + /api/data-Abruf
│   │   ├── customers.js        # Logik der Customers-Seite
│   │   └── relationships.js    # Logik der Relationships-Seite
│   └── css/daisyui.css
├── docs/
│   └── API.md                  # REST-API-Dokumentation
└── logs/                       # Logdateien (wird automatisch erstellt, nicht versioniert)
```

## Voraussetzungen

- **PowerShell 7.x** (empfohlen; `using module` und Web-Modus sind darauf getestet)
- CSP-Partner-Tenant mit bestehenden GDAP-Beziehungen
- Berechtigung, folgende Graph-Scopes zu konsentieren:
  `User.Read.All`, `Directory.Read.All`, `Identity.Governance.Read.All`,
  `DelegatedAdminRelationship.Read.All`
- Benötigte Module (werden beim Start automatisch installiert, siehe
  [.static/requirements.json](.static/requirements.json)):
  - `Microsoft.Graph.Identity.Partner`
  - `Microsoft.Graph.Identity.Governance`
  - `Pode`

## Schnellstart

### Konsolenmodus

```powershell
.\gdap-toolkit.ps1
```

Das Skript prüft die Voraussetzungen, öffnet die Graph-Anmeldung und zeigt
anschließend das Hauptmenü (Kunden / Beziehungen) an.

### Web-Modus

```powershell
Connect-MgGraph -Scopes 'DelegatedAdminRelationship.Read.All', 'Directory.Read.All'
.\server.ps1
```

Anschließend <http://localhost:8080> im Browser öffnen.

> **Wichtig:** `Connect-MgGraph` muss **in derselben PowerShell-Session** vor dem
> Serverstart ausgeführt werden – die API-Routen nutzen den Graph-Kontext des
> Serverprozesses. Ohne Verbindung liefert `/api/data` den Status 500.

## Parameter (`gdap-toolkit.ps1`)

| Parameter    | Typ      | Standard | Beschreibung                                                         |
|--------------|----------|----------|----------------------------------------------------------------------|
| `-LogLevel`  | `string` | `Info`   | Minimales Loglevel der Konsole: `Debug`, `Verbose`, `Info`, `Warning`, `Error` |
| `-NoFileLog` | `switch` | –        | Deaktiviert die Logdatei unter `.\logs`                              |
| `-Verbose`   | common   | –        | Kurzform für `-LogLevel Verbose`                                     |
| `-Debug`     | common   | –        | Kurzform für `-LogLevel Debug`                                       |

```powershell
.\gdap-toolkit.ps1 -LogLevel Verbose      # mehr Details auf der Konsole
.\gdap-toolkit.ps1 -Debug -NoFileLog      # volles Debug-Log, ohne Logdatei
Get-Help .\gdap-toolkit.ps1 -Full         # eingebaute Hilfe
```

## Logging & Debugging

Alle Komponenten loggen über das zentrale Modul
[.functions/write-log.psm1](.functions/write-log.psm1) in einem einheitlichen Format:

```text
[2026-11-03 10:58:12.345] [INFO   ] [Main] GDAP Management Toolkit gestartet.
[2026-11-03 10:58:13.012] [VERBOSE] [FetchData] Graph lieferte 42 Kunden und 57 Beziehungen.
```

- **Konsole:** zeigt Meldungen ab dem konfigurierten `-LogLevel` (farbcodiert).
- **Logdatei:** `logs\gdap-toolkit_JJJJ-MM-TT.log` erhält **immer alle** Meldungen
  (inkl. `Debug`) – ideal für die Nachanalyse. Deaktivierbar per `-NoFileLog`.
- **Web-Modus (Pode):** HTTP-Requests werden im Terminal protokolliert,
  Serverfehler zusätzlich in `logs\` abgelegt.
- **Eigene Module erweitern:** `Write-Log -Level Verbose -Component 'MeinModul' -Message '…'`

Das Verzeichnis `logs\` ist über die [.gitignore](.gitignore) von der
Versionierung ausgeschlossen.

## REST-API

| Methode | Pfad          | Beschreibung                                   |
|---------|---------------|------------------------------------------------|
| `GET`   | `/api/status` | Healthcheck                                    |
| `GET`   | `/api/data`   | Alle Kunden + GDAP-Beziehungen als JSON        |

Details, Antwortbeispiele und Datenmodelle: **[docs/API.md](docs/API.md)**

## Troubleshooting

| Problem | Ursache / Lösung |
|---------|------------------|
| Klassenänderung wirkt nicht | PowerShell cached Klassen pro Session – **neue Session starten**, `Import-Module -Force` reicht nicht. |
| `Connect-MgGraph: InteractiveBrowserCredential authentication failed` | WAM-/Browser-Login scheitert gelegentlich in eingebetteten Terminals (VS Code) oder das Anmeldefenster liegt hinter anderen Fenstern. Lösung: Anmeldefenster suchen (Taskleiste) oder manuell `Connect-MgGraph -UseDeviceCode -TenantId organizations` nutzen. |
| `AADSTS70011: … 'scope' is not valid` | Tritt beim Device-Code-Flow ohne Tenant-Kontext auf. Lösung: `Connect-MgGraph -UseDeviceCode -TenantId <GUID, Domäne oder organizations>`. |
| `Assembly with same name is already loaded` (Microsoft.Graph.Authentication) | Gemischte Versionen der `Microsoft.Graph.*`-Module installiert. Alle Graph-Module auf dieselbe Version bringen (z.B. `Install-PSResource Microsoft.Graph.Identity.Partner`) und **neue PowerShell-Session** starten. |
| `Install-Module: Unable to resolve package source` | PowerShell Gallery sporadisch nicht erreichbar (Proxy/Firewall/Endpunkt-Flattern). Erneut versuchen oder `Install-PSResource <Modul>` nutzen. |
| `/api/data` liefert 500 | Keine aktive Graph-Verbindung im Serverprozess – `Connect-MgGraph` vor `.\server.ps1` in derselben Session ausführen. |
| Web-UI ohne Styling | Das Tailwind-Browser-CDN (`cdn.jsdelivr.net`) ist nicht erreichbar (Proxy/Firewall) oder die Seite wurde per `file://` statt über <http://localhost:8080> geöffnet. |
| Port 8080 belegt | Anderen Prozess beenden oder Port in `server.ps1` (`Add-PodeEndpoint`) anpassen. |
| `using module`-Fehler | `using module` akzeptiert nur literale Pfade (keine Variablen) und muss am Dateianfang stehen. |

## Autor

[robinkiefer2001](https://github.com/robinkiefer2001)
