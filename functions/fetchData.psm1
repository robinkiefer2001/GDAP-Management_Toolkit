using module "..\classes\gdapCustomer.psm1"
using module "..\classes\gdapRelationship.psm1"

##  Datenabruf für das GDAP Management Toolkit

# Zentrales Logging laden, sofern nicht bereits vorhanden (z.B. durch gdapToolkit.ps1)
if (-not (Get-Command writeLog -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'writeLog.psm1') -DisableNameChecking
}

# Rollen-Mapping laden, sofern nicht bereits vorhanden (z.B. im Pode-Runspace)
if (-not (Get-Command getRoleMapping -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'getRoleMapping.psm1') -DisableNameChecking
}

function fetchData {
    <#
    .SYNOPSIS
        Ruft GDAP-Kunden und -Beziehungen aus Microsoft Graph ab.
    .DESCRIPTION
        Lädt alle Delegated-Admin-Kunden und -Beziehungen des Partner-Tenants,
        mappt sie auf die Klassen gdapCustomer und gdapRelationship und gibt
        beides als Hashtable zurück. Benötigt eine aktive Graph-Verbindung
        (Connect-MgGraph) mit dem Scope 'DelegatedAdminRelationship.Read.All'.
    .OUTPUTS
        hashtable mit den Schlüsseln 'customers' und 'relationships'.
    .EXAMPLE
        $data = fetchData
        $data.customers | Format-Table customerName, customerTenantId
    #>
    [CmdletBinding()]
    param ()

    writeLog -component 'fetchData' -message 'Rufe GDAP-Daten aus Microsoft Graph ab …'

    try {
        $allCustomers     = Get-MgTenantRelationshipDelegatedAdminCustomer -All -ErrorAction Stop
        $allRelationships = Get-MgTenantRelationshipDelegatedAdminRelationship -All -ErrorAction Stop
    }
    catch {
        writeLog -level Error -component 'fetchData' -message "Graph-Abruf fehlgeschlagen: $($_.Exception.Message)"
        throw
    }

    writeLog -level Verbose -component 'fetchData' -message "Graph lieferte $(@($allCustomers).Count) Kunden und $(@($allRelationships).Count) Beziehungen."

    $gdapRelationships = @()
    foreach ($relationship in $allRelationships) {
        writeLog -level Debug -component 'fetchData' -message "Verarbeite Relationship $($relationship.Id)"

        $relationshipId             = $relationship.Id
        $relationshipCustomerId     = $relationship.Customer.TenantId
        $relationshipName           = $relationship.DisplayName
        $relationshipRoles          = $relationship.AccessDetails.UnifiedRoles
        $relationshipStatus         = $relationship.Status
        $relationshipAutoExtend     = ($null -ne $relationship.AutoExtendDuration -and $relationship.AutoExtendDuration -ne [TimeSpan]::Zero)
        $relationshipStartDate      = $relationship.CreatedDateTime
        $relationshipExpirationDate = $relationship.EndDateTime

        $gdapRelationships += [gdapRelationship]::new(
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
    # Rollen-GUIDs um Entra-Anzeigenamen anreichern
    $gdapRelationships = @(getRoleMapping -relationships $gdapRelationships)

    $gdapCustomers = @()
    foreach ($customer in $allCustomers) {

        writeLog -level Debug -component 'fetchData' -message "Verarbeite Kunden-Tenant $($customer.TenantId)"

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

    $customerTenantIds = @{}
    foreach ($customer in $gdapCustomers) {
        $customerTenantIds[$customer.customerTenantId] = $true
    }

    foreach ($relationship in $allRelationships) {
        $relationshipCustomer = $relationship.Customer
        $customerTenantId = $relationshipCustomer.TenantId

        if ([string]::IsNullOrWhiteSpace($customerTenantId) -or $customerTenantIds.ContainsKey($customerTenantId)) {
            continue
        }

        writeLog -level Debug -component 'fetchData' -message "Kunde $customerTenantId fehlt in der Kundenliste; ergänze ihn aus der Relationship."

        $customerName              = $relationshipCustomer.DisplayName
        $customerId                = if ($relationshipCustomer.Id) { $relationshipCustomer.Id } else { $customerTenantId }
        $customerGdapRelationships = @($gdapRelationships | Where-Object { $_.relationshipCustomerId -eq $customerTenantId })

        $gdapCustomers += [gdapCustomer]::new(
            $customerName,
            $customerId,
            $customerTenantId,
            $customerGdapRelationships
        )
        $customerTenantIds[$customerTenantId] = $true
    }

    writeLog -component 'fetchData' -message "Mapping abgeschlossen: $($gdapCustomers.Count) Kunden, $($gdapRelationships.Count) Beziehungen."

    return @{
        customers     = $gdapCustomers
        relationships = $gdapRelationships
    }
}

Export-ModuleMember -Function fetchData
