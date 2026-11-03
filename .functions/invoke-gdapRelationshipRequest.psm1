function Invoke-GdapRelationshipRequest {
	[CmdletBinding()]
	param (
        [Parameter(Mandatory=$true)]
        [string]$DisplayName,
        [string]$Duration = "P730D",
        [Parameter(Mandatory=$true)]
        [string]$CustomerTenantId,
        [Parameter(Mandatory=$true)]
        [array]$UnifiedRoles,
        [Parameter(Mandatory=$true)]
        [string]$AutoExtendDuration = "P180D"
	)

    $params = @{
    	displayName = $DisplayName
    	duration = $Duration
    	customer = @{
    		tenantId = $CustomerTenantId
    		displayName = $DisplayName
    	}
    	accessDetails = @{
                unifiedRoles = $UnifiedRoles
    	}
    	autoExtendDuration = $AutoExtendDuration
    }

    New-MgTenantRelationshipDelegatedAdminRelationship -BodyParameter $params
}

Export-ModuleMember -Function Invoke-GdapRelationshipRequest