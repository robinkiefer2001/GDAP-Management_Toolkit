##  Prerequisite Preparation for GDAP Management Toolkit

function Install-Prerequisites {
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    Write-Host "Installing required module '$ModuleName'..."
    try {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "Module '$ModuleName' installed successfully."
    }
    catch {
        throw "Failed to install required module '$ModuleName': $_"
    }
}

Export-ModuleMember -Function Install-Prerequisites
