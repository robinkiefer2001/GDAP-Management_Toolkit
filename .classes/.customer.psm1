class gdapCustomer {
    [string]$customerName
    [string]$customerId
    [string]$customerTenantId
    [Array]$customerGdapRelationships

    gdapCustomer([string]$customerName, [string]$customerId, [string]$customerTenantId, [Array]$customerGdapRelationships) {
        $this.customerName = $customerName
        $this.customerId = $customerId
        $this.customerTenantId = $customerTenantId
        $this.customerGdapRelationships = $customerGdapRelationships
    }
}