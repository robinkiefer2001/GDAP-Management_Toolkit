function display-MainMenu {
    Write-Host "Displaying Main Menu..." -ForegroundColor yellow

    Write-Host "1. Use GDAP Management Toolkit | Console Mode"
    Write-Host "2. Get GDAP Customers"
    Write-Host "3. Get GDAP Relationships"

    $selection = Read-Host -Prompt "Please select an option from the menu"

    switch ($selection) {
        "1" { Write-Host "You selected: Use GDAP Management Toolkit | Console Mode" -ForegroundColor green }
        "2" { Write-Host "You selected: Get GDAP Customers" -ForegroundColor green }
        "3" { Write-Host "You selected: Get GDAP Relationships" -ForegroundColor green }
        default { Write-Host "Invalid selection. Please try again." -ForegroundColor red }
    }

    return $selection
}