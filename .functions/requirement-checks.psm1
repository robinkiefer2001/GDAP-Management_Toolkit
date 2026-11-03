##  Requirement Checks for GDAP Management Toolkit

Import-Module (Join-Path $PSScriptRoot 'install-prerequisites.psm1') -Force -DisableNameChecking

function Test-Requirement {
    param (
        [Parameter(Mandatory)]
        [string]$requirements
    )

    $parsed = ($requirements | ConvertFrom-Json).requirements

    foreach ($requirement in $parsed) {
        Write-Host "Checking requirement: $($requirement.name)"
        if ($requirement.name -eq "Module") {
            if (-not (Get-Module -ListAvailable -Name $requirement.module)) {
                Write-Warning "Required module '$($requirement.module)' is not installed."
                Install-Prerequisites -ModuleName $requirement.module
            } else {
                Write-Host "Required module '$($requirement.module)' is installed."
            }
        }
    }
}

Export-ModuleMember -Function Test-Requirement
