# GDAP Management Toolkit

PowerShell-Toolkit für Microsoft-CSP-Partner zur Auswertung und Verwaltung von
**GDAP-Beziehungen** (Granular Delegated Admin Privileges) über Microsoft Graph –
wahlweise im interaktiven **Konsolenmodus** oder als lokale **Weboberfläche**
(Pode-Webserver + daisyUI-Frontend).

## Features

- Abruf aller Delegated-Admin-Kunden und GDAP-Beziehungen des Partner-Tenants
- Typisierte Datenmodelle (`gdapCustomer`, `gdapRelationship`) als PowerShell-Klassen
- Interaktives Konsolenmenü (`gdapToolkit.ps1`)
- Lokale Web-UI mit Kunden-/Relationship-Drilldown, Suche und Status-Badges (`server.ps1`)
- Manage-Seite mit Übersicht offener Aufgaben (Approval Pending, noch nicht
  erstellte Anfragen) sowie Create Request: Kundensuche mit automatischer
  Tenant-ID, Rollenauswahl per Drag-and-drop oder Buttons und Einreichung zur
  Kundenfreigabe
- Refresh-Button auf allen Seiten: lädt Daten neu vom Backend und umgeht den
  Browser-Cache; Manage lädt Kunden und Rollen neu, ohne Formulareingaben zu löschen
- REST-API für eigene Integrationen (siehe [docs/api.md](docs/api.md))
- Automatische Installation fehlender PowerShell-Module
- Zentrales, konsistentes Logging mit Loglevel-Steuerung und Logdateien

## Projektstruktur

```text
GDAP-Management_Toolkit
├── gdapToolkit.ps1                    # Einstieg: Konsolenmenü
├── server.ps1                         # Einstieg: Web-Modus (Pode, Port 8080)
├── classes/
│   ├── gdapCustomer.psm1              # Klasse gdapCustomer
│   └── gdapRelationship.psm1          # Klasse gdapRelationship
├── functions/
│   ├── displayMainMenu.psm1           # Konsolen-Hauptmenü
│   ├── fetchData.psm1                 # Graph-Abruf und Datenmodelle
│   ├── getRoleMapping.psm1            # Rollen-IDs und Anzeigenamen
│   ├── installPrerequisites.psm1      # Installation fehlender Module
│   ├── invokeGdapRelationshipRequest.psm1 # Erstellung und Kundenfreigabe
│   ├── testRequirements.psm1          # Prüfung der Voraussetzungen
│   └── writeLog.psm1                  # initializeLog und writeLog
├── config/
│   └── requirements.json             # Benötigte PowerShell-Module
├── public/                           # Web-Frontend
│   ├── index.html                    # Startseite
│   ├── customers.html                # Kundenübersicht
│   ├── relationships.html            # Beziehungsübersicht
│   ├── manage.html                   # Übersicht offener Aufgaben + Create Request
│   ├── js/
│   │   ├── layout.js                 # Layout und Refresh-Button
│   │   ├── common.js                 # Gemeinsame Helfer und Daten-Cache
│   │   ├── index.js                  # Kennzahlen
│   │   ├── customers.js              # Kundenfilter und Drilldown
│   │   ├── relationships.js          # Suche, Filter und Pagination
│   │   └── manage.js                 # Übersicht, Kundenauswahl und Rollen-Drag-and-drop
│   └── css/daisyui.css
├── docs/
│   └── api.md                        # REST-API-Dokumentation
├── tests/
│   ├── buildApi.tests.ps1             # API mit simuliertem Graph
│   └── toolkit.tests.ps1              # Namen, Imports, Datenmodelle und Logging
└── logs/                             # Automatisch erstellt, nicht versioniert
```

## Voraussetzungen

- **PowerShell 7.2 oder neuer**
- CSP-Partner-Tenant mit bestehenden GDAP-Beziehungen
- Berechtigung, folgende Graph-Scopes zu konsentieren:
  `User.Read.All`, `Directory.Read.All`, `Identity.Governance.Read.All`,
  `DelegatedAdminRelationship.Read.All`
- Benötigte Module (werden beim Start automatisch installiert, siehe
  [config/requirements.json](config/requirements.json)):
  - `Microsoft.Graph.Identity.Partner`
  - `Microsoft.Graph.Identity.Governance`
  - `Microsoft.Graph.Authentication`
  - `Pode`

## Schnellstart

### Konsolenmodus

```powershell
.\gdapToolkit.ps1
```

Das Skript prüft die Voraussetzungen, öffnet die Graph-Anmeldung und zeigt
anschließend das Hauptmenü (Kunden / Beziehungen) an.

### Web-Modus

```powershell
Connect-MgGraph -Scopes 'DelegatedAdminRelationship.ReadWrite.All', 'Directory.Read.All'
.\server.ps1
```

Die Module aus [config/requirements.json](config/requirements.json) müssen für
den direkten Serverstart installiert sein; das Konsolenmenü prüft und installiert
sie automatisch. Anschließend <http://localhost:8080> im Browser öffnen.

> **Wichtig:** `Connect-MgGraph` muss **in derselben PowerShell-Session** vor dem
> Serverstart ausgeführt werden – die API-Routen nutzen den Graph-Kontext des
> Serverprozesses. Ohne Verbindung liefert `/api/data` den Status 500.
> Zum Erstellen und Einreichen von Beziehungen benötigt Manage → Create Request
> `DelegatedAdminRelationship.ReadWrite.All`; für reine Auswertungen reicht
> `DelegatedAdminRelationship.Read.All`.

Das Konsolenmenü bietet Kunden, Beziehungen und den Web-Modus. Menüpunkt 1 ist
weiterhin ein Platzhalter. Für Create Request nach einem Start über das Menü eine
Verbindung mit `DelegatedAdminRelationship.ReadWrite.All` statt nur `Read.All` herstellen.

## Namenskonvention und Umstellung

- Eigene Funktionen, Klassen, Parameter, Variablen und JSON-Felder verwenden
  **camelCase**, z.B. `fetchData`, `gdapRelationship`, `customerTenantId`.
- Eigene HTML-IDs und ihre JavaScript-Verweise verwenden ebenfalls camelCase;
  standardisierte HTML-/ARIA-/data-Attribute behalten ihre vorgeschriebene Form.
- Dateinamen folgen demselben Schema; Klassen liegen in `classes/`, Funktionen
  in `functions/`, Konfiguration in `config/`. Einzeldateien haben keine
  führenden Punkte. `.gitignore` bleibt eine vorgegebene Git-Datei.
- PowerShell-/Pode-/Graph-Befehle, deren Parameter, automatische Variablen
  (`$PSScriptRoot`, `$WebEvent`) und SDK-Eigenschaften behalten ihre vorgegebenen
  Namen. Ebenso bleiben Browser-APIs und die ausgelieferte daisyUI-CSS unverändert.
- Die Umstellung ist ein **Breaking Change**: Einstieg jetzt `gdapToolkit.ps1`,
  eigene Modulbefehle z.B. `initializeLog`, `writeLog`, `fetchData`,
  `getRoleMapping` und `invokeGdapRelationshipRequest`. Eigene API-Felder jetzt
  z.B. `displayName`, `duration`, `unifiedRoles`, `roleDisplayName`.
- Bestehende Automatisierungen und Modulimporte auf die neuen Namen umstellen.
  PowerShell-Session und Server neu starten, anschließend die Browserseite
  neu laden. Der neue Tab-Cache `gdapDataV2` verhindert die Verwendung alter
  Rollenfelder.

## Parameter (`gdapToolkit.ps1` und `server.ps1`)

| Parameter    | Typ      | Standard | Beschreibung                                                         |
|--------------|----------|----------|----------------------------------------------------------------------|
| `-logLevel`  | `string` | `Info`   | Minimales Loglevel der Konsole: `Debug`, `Verbose`, `Info`, `Warning`, `Error` |
| `-noFileLog` | `switch` | –        | Deaktiviert Logdateien, auch im Web-Modus                            |
| `-Verbose`   | common   | –        | Kurzform für `-logLevel Verbose`                                     |
| `-Debug`     | common   | –        | Kurzform für `-logLevel Debug`                                       |

```powershell
.\gdapToolkit.ps1 -logLevel Verbose      # mehr Details auf der Konsole
.\server.ps1 -Debug -noFileLog           # Web-Modus ohne Logdatei
Get-Help .\gdapToolkit.ps1 -Full         # eingebaute Hilfe
```

## Logging & Debugging

Alle Komponenten loggen über das zentrale Modul
[functions/writeLog.psm1](functions/writeLog.psm1) in einem einheitlichen Format:

```text
[2026-11-04 10:58:12.345] [INFO   ] [server] Starte Web-Modus auf http://localhost:8080.
[2026-11-04 10:58:13.012] [INFO   ] [fetchData] Mapping abgeschlossen: 42 Kunden, 57 Beziehungen.
[2026-11-04 10:58:13.020] [INFO   ] [http] GET /api/data -> 200
```

- **Konsole:** Meldungen ab `-logLevel`, farbcodiert.
- **Logdatei:** `logs/gdapToolkit_JJJJ-MM-TT.log` enthält alle Level, auch `Debug`.
  Tageswechsel werden bei jedem Schreibzugriff berücksichtigt. Frühere Logdateien
  bleiben unverändert erhalten. `-noFileLog` deaktiviert Dateiausgaben.
- **Web-Modus:** Dasselbe Format und dieselbe Konfiguration gelten auch in den
  Pode-Request- und Logging-Runspaces. HTTP-Methode, Pfad und Status werden
  asynchron protokolliert; Datenabrufe mit Objektanzahl, Validierungsfehler sowie
  beide Schritte der Beziehungserstellung werden ebenfalls erfasst.
- **Teilfehler:** Scheitert `lockForApproval`, enthält das Log die bereits
  erstellte Beziehungs-ID und einen Hinweis, nicht erneut zu erstellen.
- **Inhalt:** Keine kompletten Request-Bodies, Tokens oder Authorization-Header.
  Technische Tenant-/Beziehungs-IDs und Graph-Fehlermeldungen können enthalten
  sein; Logdateien entsprechend schützen. Mehrzeilige Meldungen werden auf eine
  Zeile normalisiert.
- **Parallelität:** Eine dateipfadbezogene Mutex-Sperre schützt Schreibzugriffe
  aus mehreren Runspaces/Prozessen. Schreibfehler und Sperr-Timeouts erscheinen
  ausdrücklich als Warnung. Keine automatische Löschung oder Aufbewahrungsfrist.
- **Eigene Module:** `writeLog -level Verbose -component 'myModule' -message '…'`

Das Verzeichnis `logs\` ist über die [.gitignore](.gitignore) von der
Versionierung ausgeschlossen.

## REST-API

| Methode | Pfad          | Beschreibung                                   |
|---------|---------------|------------------------------------------------|
| `GET`   | `/api/status` | Healthcheck                                    |
| `GET`   | `/api/data`   | Alle Kunden + GDAP-Beziehungen als JSON        |
| `GET`   | `/api/customers` | Bekannte Kunden für die Tenant-Auswahl       |
| `GET`   | `/api/roles` | Aktivierte integrierte Entra-Rollen             |
| `POST`  | `/api/relationship` | Beziehung erstellen und zur Freigabe einreichen |

Details, Antwortbeispiele und Datenmodelle: **[docs/api.md](docs/api.md)**

## Tests

Die Build-API-Tests prüfen die Routen und den zweistufigen Erstellungsablauf mit
simulierten Graph-Aufrufen. Die Toolkit-Tests prüfen Namenskonventionen, DOM-IDs,
Modulimporte, Datenmodelle, leere Ergebnisse und parallele Logzugriffe. Beide
benötigen keine Anmeldung und legen keine echten Beziehungen an:

```powershell
pwsh -NoProfile -File tests/buildApi.tests.ps1
pwsh -NoProfile -File tests/toolkit.tests.ps1
```

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
| Port 8080 belegt | Der Server prüft den Port vor dem Pode-Start. Die bereits laufende Instanz in ihrer PowerShell-/VS-Code-Konsole mit **Strg+C** stoppen, dann erneut starten. Nicht den gesamten VS-Code-PowerShell-Prozess beenden. Unter Linux zeigt `ss -ltnp 'sport = :8080'` den Listener. |
| Graph-`PipelineStoppedException` zusammen mit `Address already in use` | Zuerst den Portkonflikt lösen; die Pipeline-Meldungen können beim abgebrochenen Pode-Start entstehen. Bleiben sie ohne Portkonflikt bestehen, eine neue PowerShell-Session starten und Graph erneut verbinden. |
| `using module`-Fehler | `using module` akzeptiert nur literale Pfade (keine Variablen) und muss am Dateianfang stehen. |

## Autor

[robinkiefer2001](https://github.com/robinkiefer2001)
