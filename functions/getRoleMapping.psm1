##  Rollen-Mapping für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command writeLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'writeLog.psm1') -DisableNameChecking
}

function getRoleMapping {
    <#
    .SYNOPSIS
        Reichert die Rollen von GDAP-Beziehungen um Entra-Anzeigenamen an.
    .DESCRIPTION
        Lädt alle Directory-Rollendefinitionen aus Microsoft Graph und ersetzt
        die Einträge in relationshipRoles durch Objekte mit roleDefinitionId
        und roleDisplayName. Unbekannte IDs behalten die GUID als Anzeigename.
    .PARAMETER relationships
        Array von GdapRelationship-Objekten, deren Rollen übersetzt werden sollen.
    .OUTPUTS
        Dieselben (angereicherten) GdapRelationship-Objekte.
    .EXAMPLE
        $gdapRelationships = @(getRoleMapping -relationships $gdapRelationships)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$relationships
    )

    writeLog -level Verbose -component 'getRoleMapping' -message 'Lade Entra-Rollendefinitionen …'
    $roles = Get-MgRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop

    # Lookup-Tabelle: TemplateId/Id -> DisplayName (GDAP-Rollen referenzieren die Template-GUID)
    $roleNames = @{}
    foreach ($role in $roles) {
        if ($role.TemplateId) { $roleNames[$role.TemplateId] = $role.DisplayName }
        if ($role.Id -and -not $roleNames.ContainsKey($role.Id)) { $roleNames[$role.Id] = $role.DisplayName }
    }
    writeLog -level Verbose -component 'getRoleMapping' -message "$($roleNames.Count) Rollendefinitionen geladen."

    foreach ($relationship in $relationships) {
        $relationship.relationshipRoles = @(
            foreach ($roleEntry in $relationship.relationshipRoles) {
                $id = $roleEntry.RoleDefinitionId
                $displayName = if ($roleNames.ContainsKey($id)) { $roleNames[$id] } else {
                    writeLog -level Debug -component 'getRoleMapping' -message "Keine Rollendefinition für '$id' gefunden."
                    $id
                }
                [pscustomobject]@{
                    roleDefinitionId = $id
                    roleDisplayName  = $displayName
                }
            }
        )
    }

    return $relationships
}

Export-ModuleMember -Function getRoleMapping
