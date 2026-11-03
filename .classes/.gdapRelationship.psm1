class GdapRelationship {
    [string]$relationshipId
    [string]$relationshipCustomerId
    [string]$relationshipName
    [Array]$relationshipRoles
    [string]$relationshipStatus
    [bool]$relationshipAutoExtend
    [Nullable[datetime]]$relationshipStartDate
    [Nullable[datetime]]$relationshipExpirationDate

    GdapRelationship([string]$relationshipId, [string]$relationshipCustomerId, [string]$relationshipName, [Array]$relationshipRoles, [string]$relationshipStatus, [bool]$relationshipAutoExtend, [Nullable[datetime]]$relationshipStartDate, [Nullable[datetime]]$relationshipExpirationDate) {
        $this.relationshipId = $relationshipId
        $this.relationshipCustomerId = $relationshipCustomerId
        $this.relationshipName = $relationshipName
        $this.relationshipRoles = $relationshipRoles
        $this.relationshipStatus = $relationshipStatus
        $this.relationshipAutoExtend = $relationshipAutoExtend
        $this.relationshipStartDate = $relationshipStartDate
        $this.relationshipExpirationDate = $relationshipExpirationDate
    }
}