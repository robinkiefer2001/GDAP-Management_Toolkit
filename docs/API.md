# REST-API – GDAP Management Toolkit

Die API wird vom Pode-Webserver ([server.ps1](../server.ps1)) bereitgestellt.

- **Base-URL:** `http://localhost:8080`
- **Format:** JSON (UTF-8)
- **Authentifizierung:** keine eigene – die API nutzt die Microsoft-Graph-Verbindung
  des Serverprozesses (`Connect-MgGraph` vor dem Serverstart in derselben Session).

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
(`fetch-data`, siehe [.functions/fetch-data.psm1](../.functions/fetch-data.psm1)).

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
      "customerGdapRelationships": [ { "…": "GdapRelationship-Objekte, s.u." } ]
    }
  ],
  "relationships": [
    {
      "relationshipId": "5d16…-…",
      "relationshipCustomerId": "d4c8…",
      "relationshipName": "Global_Admin_Contoso",
      "relationshipRoles": [ { "RoleDefinitionId": "62e90394-69f5-4237-9190-012177145e10" } ],
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

## Datenmodelle

### `customer` (Klasse [`gdapCustomer`](../.classes/.customer.psm1))

| Feld                        | Typ        | Beschreibung                                      |
|-----------------------------|------------|---------------------------------------------------|
| `customerName`              | `string`   | Anzeigename des Kunden                            |
| `customerId`                | `string`   | ID des Delegated-Admin-Kunden                     |
| `customerTenantId`          | `string`   | Entra-Tenant-ID des Kunden                        |
| `customerGdapRelationships` | `array`    | Alle `relationship`-Objekte dieses Kunden         |

### `relationship` (Klasse [`GdapRelationship`](../.classes/.gdapRelationship.psm1))

| Feld                         | Typ               | Beschreibung                                                |
|------------------------------|-------------------|-------------------------------------------------------------|
| `relationshipId`             | `string`          | ID der GDAP-Beziehung                                        |
| `relationshipCustomerId`     | `string`          | Tenant-ID des zugehörigen Kunden                             |
| `relationshipName`           | `string`          | Anzeigename der Beziehung                                    |
| `relationshipRoles`          | `array`           | Entra-Rollen (`RoleDefinitionId` je Rolle)                   |
| `relationshipStatus`         | `string`          | Graph-Status, z.B. `active`, `created`, `terminated`         |
| `relationshipAutoExtend`     | `bool`            | `true`, wenn eine Auto-Extend-Dauer (> 0) konfiguriert ist   |
| `relationshipStartDate`      | `datetime\|null`  | Erstellungszeitpunkt (`createdDateTime`)                     |
| `relationshipExpirationDate` | `datetime\|null`  | Ablaufzeitpunkt (`endDateTime`); `null`, wenn nicht gesetzt  |

---

## Statische Routen

| Pfad               | Quelle                  | Beschreibung              |
|--------------------|-------------------------|---------------------------|
| `/` und alle Dateien | [public/](../public)  | Web-UI (`index.html` als Default-Dokument) |
