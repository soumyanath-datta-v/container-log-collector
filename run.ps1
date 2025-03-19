# Log collector entry point script

# Set the path to the log collector script
$logCollectorScript = ".\scripts\log-collector.ps1"

# Check if the log collector script exists
if (Test-Path $logCollectorScript) {
    # Execute the log collector script
    & $logCollectorScript
} else {
    Write-Host "Log collector script not found: $logCollectorScript"
}