using module "..\.classes\.customer.psm1"
using module "..\.classes\.gdapRelationship.psm1"

##  Datenabruf für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden (z.B. durch gdap-toolkit.ps1)
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'write-log.psm1') -DisableNameChecking
}

function fetch-data {
    <#
    .SYNOPSIS
        Ruft GDAP-Kunden und -Beziehungen aus Microsoft Graph ab.
    .DESCRIPTION
        Lädt alle Delegated-Admin-Kunden und -Beziehungen des Partner-Tenants,
        mappt sie auf die Klassen gdapCustomer und GdapRelationship und gibt
        beides als Hashtable zurück. Benötigt eine aktive Graph-Verbindung
        (Connect-MgGraph) mit dem Scope 'DelegatedAdminRelationship.Read.All'.
    .OUTPUTS
        hashtable mit den Schlüsseln 'Customers' und 'Relationships'.
    .EXAMPLE
        $data = fetch-data
        $data.Customers | Format-Table customerName, customerTenantId
    #>
    [CmdletBinding()]
    param ()

    Write-Log -Level Verbose -Component 'FetchData' -Message 'Rufe GDAP-Daten aus Microsoft Graph ab …'

    try {
        $allCustomers     = Get-MgTenantRelationshipDelegatedAdminCustomer -ErrorAction Stop
        $allRelationships = Get-MgTenantRelationshipDelegatedAdminRelationship -ErrorAction Stop
    }
    catch {
        Write-Log -Level Error -Component 'FetchData' -Message "Graph-Abruf fehlgeschlagen: $($_.Exception.Message)"
        throw
    }

    Write-Log -Level Verbose -Component 'FetchData' -Message "Graph lieferte $(@($allCustomers).Count) Kunden und $(@($allRelationships).Count) Beziehungen."

    $gdapRelationships = @()
    foreach ($relationship in $allRelationships) {

        Write-Log -Level Debug -Component 'FetchData' -Message "Verarbeite Relationship '$($relationship.DisplayName)' ($($relationship.Id))"

        $relationshipId             = $relationship.Id
        $relationshipCustomerId     = $relationship.Customer.TenantId
        $relationshipName           = $relationship.DisplayName
        $relationshipRoles          = $relationship.AccessDetails.UnifiedRoles
        $relationshipStatus         = $relationship.Status
        $relationshipAutoExtend     = ($null -ne $relationship.AutoExtendDuration -and $relationship.AutoExtendDuration -ne [TimeSpan]::Zero)
        $relationshipStartDate      = $relationship.CreatedDateTime
        $relationshipExpirationDate = $relationship.EndDateTime

        $gdapRelationships += [GdapRelationship]::new(
            $relationshipId,
            $relationshipCustomerId,
            $relationshipName,
            $relationshipRoles,
            $relationshipStatus,
            $relationshipAutoExtend,
            $relationshipStartDate,
            $relationshipExpirationDate
        )
    }

    $gdapCustomers = @()
    foreach ($customer in $allCustomers) {

        Write-Log -Level Debug -Component 'FetchData' -Message "Verarbeite Kunde '$($customer.DisplayName)' ($($customer.TenantId))"

        $customerName              = $customer.DisplayName
        $customerId                = $customer.Id
        $customerTenantId          = $customer.TenantId
        $customerGdapRelationships = @($gdapRelationships | Where-Object { $_.relationshipCustomerId -eq $customer.TenantId })

        $gdapCustomers += [gdapCustomer]::new(
            $customerName,
            $customerId,
            $customerTenantId,
            $customerGdapRelationships
        )
    }

    Write-Log -Level Verbose -Component 'FetchData' -Message "Mapping abgeschlossen: $($gdapCustomers.Count) Kunden, $($gdapRelationships.Count) Beziehungen."

    return @{
        Customers     = $gdapCustomers
        Relationships = $gdapRelationships
    }
}

Export-ModuleMember -Function fetch-data
