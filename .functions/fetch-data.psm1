using module "..\.classes\.customer.psm1"
using module "..\.classes\.gdapRelationship.psm1"

function fetch-data {
    $allCustomers = Get-MgTenantRelationshipDelegatedAdminCustomer
    $allRelationships = Get-MgTenantRelationshipDelegatedAdminRelationship

    $gdapRelationships = @()
    foreach ($relationship in $allRelationships) {

        $relationshipId             = $relationship.Id
        $relationshipCustomerId     = $relationship.Customer.TenantId
        $relationshipName           = $relationship.DisplayName
        $relationshipRoles          = $relationship.AccessDetails.UnifiedRoles
        $relationshipStatus         = $relationship.Status
        $relationshipAutoExtend     = ($null -ne $relationship.AutoExtendDuration -and $relationship.AutoExtendDuration -ne [TimeSpan]::Zero)
        $relationshipStartDate      = ($relationship.CreatedDateTime -ne $null) ? $relationship.CreatedDateTime : $null
        $relationshipExpirationDate = ($relationship.EndDateTime -ne $null) ? $relationship.EndDateTime : $null

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

    return @{
        Customers = $gdapCustomers
        Relationships = $gdapRelationships
    }

}