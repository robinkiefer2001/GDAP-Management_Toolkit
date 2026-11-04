if (-not (Get-Command writeLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'writeLog.psm1') -DisableNameChecking
}

function invokeGdapRelationshipRequest {
    <#
    .SYNOPSIS
        Erstellt eine GDAP-Beziehung und reicht sie mit lockForApproval ein.
    .DESCRIPTION
        Gibt die Graph-Erstellungsantwort zurück. Bei fehlgeschlagener Einreichung
        enthält Exception.Data die bereits erstellte createdRelationshipId.
        Benötigt DelegatedAdminRelationship.ReadWrite.All. Versendet keine E-Mail.
    #>
    [CmdletBinding()]
    param (
        [string]$displayName,

        [string]$duration = 'P730D',

        [Parameter(Mandatory = $true)]
        [string]$customerTenantId,

        [Parameter(Mandatory = $true)]
        [array]$unifiedRoles,

        [string]$autoExtendDuration = 'P180D'
    )

    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = "managed-relationship-" + ([guid]::NewGuid().ToString())
    }

    $params = @{
        displayName = $displayName
        duration    = $duration
        customer    = @{
            tenantId    = $customerTenantId
            displayName = $displayName
        }
        accessDetails = @{
            unifiedRoles = $unifiedRoles
        }
        autoExtendDuration = $autoExtendDuration
    }

    writeLog -component 'invokeGdapRelationshipRequest' -message "Erstelle Beziehung für Tenant $customerTenantId mit $($unifiedRoles.Count) Rollen."
    try {
        $relationship = New-MgTenantRelationshipDelegatedAdminRelationship `
            -BodyParameter $params `
            -ErrorAction Stop
    }
    catch {
        writeLog -level Error -component 'invokeGdapRelationshipRequest' -message "Erstellung fehlgeschlagen: $($_.Exception.Message)"
        throw
    }
    writeLog -component 'invokeGdapRelationshipRequest' -message "Beziehung $($relationship.Id) erstellt; reiche Kundenfreigabe ein."

    try {
        New-MgTenantRelationshipDelegatedAdminRelationshipRequest `
            -DelegatedAdminRelationshipId $relationship.Id `
            -BodyParameter @{ action = 'lockForApproval' } `
            -ErrorAction Stop |
            Out-Null
    }
    catch {
        $_.Exception.Data['createdRelationshipId'] = $relationship.Id
        $_.Exception.Data['createdRelationshipDisplayName'] = $relationship.DisplayName
        writeLog -level Error -component 'invokeGdapRelationshipRequest' -message "Beziehung $($relationship.Id) bereits erstellt, aber Kundenfreigabe fehlgeschlagen. Nicht erneut erstellen. $($_.Exception.Message)"
        throw
    }

    writeLog -component 'invokeGdapRelationshipRequest' -message "Kundenfreigabe für Beziehung $($relationship.Id) eingereicht; Genehmigung ausstehend."
    return $relationship
}

Export-ModuleMember -Function invokeGdapRelationshipRequest