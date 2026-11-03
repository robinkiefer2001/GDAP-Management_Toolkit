##  Rollen-Mapping für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'write-log.psm1') -DisableNameChecking
}

function Get-RoleMapping {
    <#
    .SYNOPSIS
        Reichert die Rollen von GDAP-Beziehungen um Entra-Anzeigenamen an.
    .DESCRIPTION
        Lädt alle Directory-Rollendefinitionen aus Microsoft Graph und ersetzt
        die Einträge in relationshipRoles durch Objekte mit RoleDefinitionId
        und RoleDisplayName. Unbekannte IDs behalten die GUID als Anzeigename.
    .PARAMETER Relationships
        Array von GdapRelationship-Objekten, deren Rollen übersetzt werden sollen.
    .OUTPUTS
        Dieselben (angereicherten) GdapRelationship-Objekte.
    .EXAMPLE
        $gdapRelationships = @(Get-RoleMapping -Relationships $gdapRelationships)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [array]$Relationships
    )

    Write-Log -Level Verbose -Component 'RoleMapping' -Message 'Lade Entra-Rollendefinitionen …'
    $roles = Get-MgRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop

    # Lookup-Tabelle: TemplateId/Id -> DisplayName (GDAP-Rollen referenzieren die Template-GUID)
    $roleNames = @{}
    foreach ($role in $roles) {
        if ($role.TemplateId) { $roleNames[$role.TemplateId] = $role.DisplayName }
        if ($role.Id -and -not $roleNames.ContainsKey($role.Id)) { $roleNames[$role.Id] = $role.DisplayName }
    }
    Write-Log -Level Verbose -Component 'RoleMapping' -Message "$($roleNames.Count) Rollendefinitionen geladen."

    foreach ($relationship in $Relationships) {
        $relationship.relationshipRoles = @(
            foreach ($roleEntry in $relationship.relationshipRoles) {
                $id = $roleEntry.RoleDefinitionId
                $displayName = if ($roleNames.ContainsKey($id)) { $roleNames[$id] } else {
                    Write-Log -Level Debug -Component 'RoleMapping' -Message "Keine Rollendefinition für '$id' gefunden."
                    $id
                }
                [pscustomobject]@{
                    RoleDefinitionId = $id
                    RoleDisplayName  = $displayName
                }
            }
        )
    }

    return $Relationships
}

Export-ModuleMember -Function Get-RoleMapping
