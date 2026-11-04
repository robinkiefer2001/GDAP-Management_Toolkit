# REST-API – GDAP Management Toolkit

Die API wird vom Pode-Webserver ([server.ps1](../server.ps1)) bereitgestellt.

- **Base-URL:** `http://localhost:8080`
- **Format:** JSON (UTF-8)
- **Authentifizierung:** keine eigene – die API nutzt die Microsoft-Graph-Verbindung
  des Serverprozesses (`Connect-MgGraph` vor dem Serverstart in derselben Session).
- **Namenskonvention:** Eigene JSON-Felder verwenden camelCase, einschließlich
  `roleDefinitionId` und `roleDisplayName` in Rollenlisten. Graph- und
  PowerShell-SDK-Namen bleiben unverändert.
- **Refresh:** GET-Endpunkte rufen Graph live ab. Die Weboberfläche speichert
  `/api/data` pro Tab unter `gdapDataV2`; Refresh umgeht diesen Cache und den
  HTTP-Cache. Build aktualisiert `/api/customers` und `/api/roles` parallel.
- **Logging:** Alle Endpunkte verwenden das gemeinsame Logging aus
  [writeLog.psm1](../functions/writeLog.psm1). HTTP-Methode, Pfad und Status,
  Mengen der geladenen Objekte, Erstellung, Freigabe und Fehler werden erfasst.
  Keine Request-Bodies, Authorization-Header oder Tokens; Graph-Fehlermeldungen
  können technische IDs enthalten. Details und Optionen siehe [readme.md](../readme.md).

---

## `GET /api/status`

Healthcheck – prüft, ob das PowerShell-Backend erreichbar ist.

**Beispiel**

```bash
curl http://localhost:8080/api/status
```

**Antwort `200 OK`**

```json
{
  "status": "ok",
  "message": "PowerShell-Backend erreichbar"
}
```

---

## `GET /api/data`

Liefert alle Delegated-Admin-Kunden und GDAP-Beziehungen des Partner-Tenants.
Die Daten werden bei jedem Aufruf live über Microsoft Graph abgerufen
(`fetchData`, siehe [functions/fetchData.psm1](../functions/fetchData.psm1)).

**Beispiel**

```bash
curl http://localhost:8080/api/data
```

**Antwort `200 OK`**

```json
{
  "customers": [
    {
      "customerName": "Contoso AG",
      "customerId": "f3a5…",
      "customerTenantId": "d4c8…",
      "customerGdapRelationships": [ { "…": "gdapRelationship-Objekte, s.u." } ]
    }
  ],
  "relationships": [
    {
      "relationshipId": "5d16…-…",
      "relationshipCustomerId": "d4c8…",
      "relationshipName": "Global_Admin_Contoso",
      "relationshipRoles": [ { "roleDefinitionId": "62e90394-69f5-4237-9190-012177145e10", "roleDisplayName": "Global Administrator" } ],
      "relationshipStatus": "active",
      "relationshipAutoExtend": true,
      "relationshipStartDate": "2024-02-19T13:44:49",
      "relationshipExpirationDate": "2026-02-19T13:44:49"
    }
  ]
}
```

**Antwort `500 Internal Server Error`**

Tritt auf, wenn der Graph-Abruf fehlschlägt (z.B. keine aktive Graph-Verbindung
im Serverprozess). Der Fehler wird zusätzlich in `logs\` protokolliert.

```json
{
  "error": "Authentication needed. Please call Connect-MgGraph."
}
```

---

## `GET /api/customers`

Liefert alle bekannten Delegated-Admin-Kunden (einschließlich aller Graph-Seiten),
alphabetisch sortiert, ohne Beziehungen und Rollen-Mapping zu laden.
Die Kundensuche in Build filtert diese Liste nach Name oder Tenant-ID.
Die Tenant-ID kann weiterhin manuell eingegeben werden.

**Antwort `200 OK`**

```json
{
  "customers": [
    { "displayName": "Contoso AG", "tenantId": "11111111-1111-1111-1111-111111111111" }
  ]
}
```

Graph-Fehler liefern `502` mit `{ "error": "…" }` und werden protokolliert.

## `GET /api/roles`

Liefert aktivierte integrierte Entra-Rollen als
`{ "roles": [{ "id": "<Rollen-GUID>", "displayName": "…", "description": "…" }] }`.
Alle Graph-Seiten werden geladen. Die GDAP-Eignung prüft Graph beim Erstellen.
Graph-Fehler liefern `502` mit `{ "error": "…" }`.
Benötigt z.B. `Directory.Read.All`.

## `POST /api/relationship`

Erstellt eine GDAP-Beziehung und reicht sie anschließend mit `lockForApproval`
zur Kundenfreigabe ein. Benötigt `DelegatedAdminRelationship.ReadWrite.All`.
Erst die Genehmigung des Kunden aktiviert die Beziehung; die API versendet
keine E-Mail. Das Build-Formular erlaubt Rollenauswahl per Drag-and-drop oder
über tastaturbedienbare Hinzufügen-/Entfernen-Buttons.

Content-Type muss `application/json` sein. Browser-Origin, falls vorhanden,
muss `http://localhost:8080` sein.

```json
{
  "displayName": "Contoso-Admin-2026",
  "customerTenantId": "11111111-1111-1111-1111-111111111111",
  "duration": "P730D",
  "autoExtendDuration": "P180D",
  "unifiedRoles": [
    { "roleDefinitionId": "729827e3-9c14-49f7-bb1b-9608f156bbb8" }
  ]
}
```

Name: 1–50 Zeichen; Tenant-ID und Rollen-IDs: nicht-leere GUIDs; mindestens
eine Rolle. Laufzeit: `P1D`–`P730D` (Standard `P730D`). Auto-Extend:
`P180D` (Standard), `PT0S` oder `P0D`. Global Administrator ist nicht mit
`P180D` kombinierbar.

**Antwort `201 Created`**

```json
{
  "status": "approvalRequested",
  "relationshipCreated": true,
  "approvalSubmitted": true,
  "result": {
    "id": "<Beziehungs-ID>",
    "displayName": "Contoso-Admin-2026",
    "status": "created",
    "duration": "730.00:00:00"
  }
}
```

`result.status` und `result.duration` stammen aus der Graph-Erstellungsantwort,
nicht aus einem erneuten Statusabruf. `approvalSubmitted` bestätigt die erfolgreiche
Einreichung, nicht die Kundenfreigabe.

Validierungsfehler liefern `400`, unzulässige Origin `403`, falscher Content-Type
`415`. Graph-Fehler liefern `502` bzw. den Upstream-Status
`400`, `401`, `403`, `404`, `409` oder `429`.

**Teilfehler: Erstellung erfolgreich, Einreichung fehlgeschlagen**

```json
{
  "error": "Fehler beim Einreichen zur Freigabe",
  "relationshipCreated": true,
  "approvalSubmitted": false,
  "result": { "id": "<Beziehungs-ID>", "displayName": "Contoso-Admin-2026" }
}
```

Nicht erneut erstellen: Die bestehende Beziehung über ihre ID prüfen und deren
Freigabe separat einreichen. Bei Netzwerkfehlern kann das Ergebnis unbekannt sein;
auch dann vor einem erneuten POST unter Relationships nachsehen.

---

## Datenmodelle

### `customer` (Klasse [`gdapCustomer`](../classes/gdapCustomer.psm1))

| Feld                        | Typ        | Beschreibung                                      |
|-----------------------------|------------|---------------------------------------------------|
| `customerName`              | `string`   | Anzeigename des Kunden                            |
| `customerId`                | `string`   | ID des Delegated-Admin-Kunden                     |
| `customerTenantId`          | `string`   | Entra-Tenant-ID des Kunden                        |
| `customerGdapRelationships` | `array`    | Alle `relationship`-Objekte dieses Kunden         |

### `relationship` (Klasse [`gdapRelationship`](../classes/gdapRelationship.psm1))

| Feld                         | Typ               | Beschreibung                                                |
|------------------------------|-------------------|-------------------------------------------------------------|
| `relationshipId`             | `string`          | ID der GDAP-Beziehung                                        |
| `relationshipCustomerId`     | `string`          | Tenant-ID des zugehörigen Kunden                             |
| `relationshipName`           | `string`          | Anzeigename der Beziehung                                    |
| `relationshipRoles`          | `array`           | Entra-Rollen (`roleDefinitionId` + `roleDisplayName` je Rolle)       |
| `relationshipStatus`         | `string`          | Graph-Status, z.B. `active`, `created`, `terminated`         |
| `relationshipAutoExtend`     | `bool`            | `true`, wenn eine Auto-Extend-Dauer (> 0) konfiguriert ist   |
| `relationshipStartDate`      | `datetime\|null`  | Erstellungszeitpunkt (`createdDateTime`)                     |
| `relationshipExpirationDate` | `datetime\|null`  | Ablaufzeitpunkt (`endDateTime`); `null`, wenn nicht gesetzt  |

---

## Statische Routen

| Pfad               | Quelle                  | Beschreibung              |
|--------------------|-------------------------|---------------------------|
| `/` und alle Dateien | [public/](../public)  | Web-UI (`index.html` als Default-Dokument) |
