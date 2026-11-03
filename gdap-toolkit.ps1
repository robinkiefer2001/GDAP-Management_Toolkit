##  GDAP Management Toolkit

# $PSScriptRoot is empty when lines are run interactively; fall back to the current directory
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

foreach ($module in Get-ChildItem -Path (Join-Path $scriptRoot ".functions") -Filter "*.psm1") {
    Import-Module $module.FullName -Force -DisableNameChecking
}

$requirementsJson = Get-Content (Join-Path $scriptRoot '.static\requirements.json') -Raw
Test-Requirement -requirements $requirementsJson

connect-graph -Scopes "User.Read.All","Directory.Read.All","Identity.Governance.Read.All"

$data = fetch-data

$menuSelection = display-MainMenu

switch ($menuSelection) {
    "1" { Write-Host "You selected: Get GDAP Customers" -ForegroundColor green }
    "2" { Write-Host "You selected: Get GDAP Relationships" -ForegroundColor green }
    default { Write-Host "Invalid selection. Please try again." -ForegroundColor red }
}

switch ($menuSelection) {
    "1" { $data.Customers }
    "2" { $data.Relationships }
}


