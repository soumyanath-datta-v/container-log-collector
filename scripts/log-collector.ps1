# Base log file paths
$logsFolder = "pod-logs"  # Folder for individual pod logs
$logFileBase = "app-state-prod"
$logFileExt = ".log"
$combinedLogFile = "$logFileBase$logFileExt"
$maxLogSizeMB = 100

# Boolean flag to control the main loop
$global:continue = $true

# Ensure logs folder exists
if (-not (Test-Path -Path $logsFolder)) {
    New-Item -ItemType Directory -Path $logsFolder | Out-Null
}

# Register PowerShell's native event handler for Ctrl+C
$job = Register-ObjectEvent -InputObject ([System.Console]) -EventName CancelKeyPress -Action {
    Write-Host "`nCtrl+C detected! Combining logs and splitting the combined file..."
    $global:continue = $false
    # Prevent immediate exit
    $event.Cancel = $true
}

# Function to get next available log file name
function Get-NextLogFileName {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    return "$logFileBase-$timestamp$logFileExt"
}

# Function to split large log file into smaller chunks
function Split-LogFile {
    param (
        [string]$logFilePath,
        [int]$maxSizeMB = 100
    )

    if (-not (Test-Path $logFilePath)) {
        Write-Host "Log file not found: $logFilePath"
        return
    }

    $fileInfo = Get-Item $logFilePath
    $fileSizeMB = $fileInfo.Length / 1MB

    # Only split if file is larger than max size
    if ($fileSizeMB -le $maxSizeMB) {
        Write-Host "Log file is smaller than $maxSizeMB MB. No splitting needed."
        return
    }

    Write-Host "Breaking down log file ($([math]::Round($fileSizeMB, 2)) MB) into $maxSizeMB MB chunks..."

    # Read the entire file content
    $content = Get-Content -Path $logFilePath -Raw
    
    # Calculate approximate chunk size (in bytes)
    $maxSizeBytes = $maxSizeMB * 1MB
    
    # Split content into chunks
    $fileCount = 0
    $offset = 0
    $totalSize = $content.Length
    
    while ($offset -lt $totalSize) {
        $fileCount++
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $chunkFileName = "$logFileBase-part$fileCount-$timestamp$logFileExt"
        
        # Calculate end position for this chunk
        $endPos = [Math]::Min($offset + $maxSizeBytes, $totalSize)
        
        # Find a good boundary (newline) to split on
        if ($endPos -lt $totalSize) {
            # Look for the next newline after the calculated position
            $newlinePos = $content.IndexOf("`n", $endPos)
            if ($newlinePos -gt 0) {
                $endPos = $newlinePos + 1
            }
        }
        
        # Extract chunk and save to file
        $chunk = $content.Substring($offset, $endPos - $offset)
        $chunk | Out-File -FilePath $chunkFileName
        
        Write-Host "Created file: $chunkFileName ($(($chunk.Length / 1MB).ToString('0.00')) MB)"
        
        $offset = $endPos
    }
    
    Write-Host "Log file has been split into $fileCount files."
    
    # Rename the original file
    $backupName = "$logFileBase-original-$(Get-Date -Format 'yyyyMMdd-HHmmss')$logFileExt"
    Rename-Item -Path $logFilePath -NewName $backupName
    Write-Host "Original log file renamed to: $backupName"
}

# Function to combine all pod logs into one file
# Function to combine all pod logs into one file without duplicates
# Function to combine all pod logs into one file (using only the latest collection)
function Merge-Logs {
    # Create combined log file with header
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $combinedLogFile -Value "===== Combined Log File - Created at $timestamp ====="
    
    # Get all individual pod log files
    $podLogFiles = Get-ChildItem -Path $logsFolder -Filter "*.log"
    
    if ($podLogFiles.Count -eq 0) {
        Write-Host "No pod log files found to combine."
        return
    }
    
    Write-Host "Combining the latest logs from $($podLogFiles.Count) pods..."
    
    # Add each pod's latest log collection to the combined file
    foreach ($podLog in $podLogFiles) {
        $podName = $podLog.BaseName
        Add-Content -Path $combinedLogFile -Value "`n`n===== Logs from pod: $podName =====`n"
        
        # Read the log file content
        $content = Get-Content -Path $podLog.FullName -Raw
        
        # Split the content by collection markers
        $collectionPattern = "===== Log collection for pod $podName"
        $collections = $content -split "(?=$collectionPattern)"
        
        # Skip the first empty element if it exists
        if ($collections[0].Trim() -eq "") {
            $collections = $collections[1..$collections.Length]
        }
        
        if ($collections.Count -eq 0) {
            Write-Host "  No collections found for $podName"
            continue
        }
        
        # Get the last collection (most recent)
        $lastCollection = $collections[$collections.Count - 1]
        
        # Add the last collection to the combined file
        Add-Content -Path $combinedLogFile -Value $lastCollection
        
        Write-Host "  Added latest collection for $podName"
    }
    
    Write-Host "All pod logs combined into $combinedLogFile (latest collections only)"
}

# Function to get logs from mymobility pods
function Get-MymobilityPodLogs {
    # Add timestamp header to console
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "===== Log collection started at $timestamp ====="
    
    # Get all mymobility pods
    $podsOutput = kubectl get pods -n prod | Select-String 'mymobility'
    
    # Process each pod line
    foreach ($podLine in $podsOutput) {
        # Extract pod name (first column)
        $podName = ($podLine -split '\s+')[0]
        
        # Skip pods with apps or platform-api or daemon in the name
        if ($podName -match "mymobility-apps" -or $podName -match "mymobility-platform-api" -or $podName -match "mymobility-daemon") {
            Write-Host "Skipping $podName"
            continue
        }
        
        # Create or append to pod-specific log file
        $podLogFile = Join-Path -Path $logsFolder -ChildPath "$podName.log"
        
        # Log which pod we're processing
        Write-Host "Processing $podName"
        
        # Add pod collection timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if (-not (Test-Path $podLogFile)) {
            # Create new log file with header
            Set-Content -Path $podLogFile -Value "===== Log collection for pod $podName started at $timestamp ====="
        } else {
            # Append to existing log file
            Add-Content -Path $podLogFile -Value "`n===== Log collection for pod $podName at $timestamp ====="
        }
        
        try {
            # Get logs without -it flag (not suitable for non-interactive scripts)
            $podLogs = kubectl exec $podName -n prod -- cat app-state.log 2>&1
            if ($LASTEXITCODE -eq 0) {
                Add-Content -Path $podLogFile -Value $podLogs
            } else {
                Add-Content -Path $podLogFile -Value "Error retrieving logs from $podName (Exit code: $LASTEXITCODE)"
            }
        }
        catch {
            Add-Content -Path $podLogFile -Value "Exception retrieving logs from $podName`: $($_.Exception.Message)"
        }
    }
    
    # Add completion timestamp to console
    $endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "===== Log collection completed at $endTime ====="
}

# Function to cleanup and exit
function Exit-LogCollector {
    Write-Host "Performing cleanup before exit..."
    
    # Combine all individual pod logs into one file
    Merge-Logs
    
    # Split the combined log file if it exists and is large enough
    if (Test-Path $combinedLogFile) {
        Split-LogFile -logFilePath $combinedLogFile -maxSizeMB $maxLogSizeMB
    }
    
    # Clean up the event job
    if ($null -ne $job) {
        Unregister-Event -SubscriptionId $job.Id -Force
        Remove-Job -Id $job.Id -Force
    }
    
    Write-Host "Log collector has completed successfully."
    exit 0
}

# Main execution loop
Write-Host "Starting mymobility pod log collection with individual pod log files."
Write-Host "Individual pod logs will be saved in the '$logsFolder' folder."
Write-Host "Press Ctrl+C to stop the script, combine logs, and split the combined file for easier browsing."

try {
    while ($global:continue) {
        $currentTime = Get-Date -Format "HH:mm:ss"
        Write-Host "`nStarting collection at $currentTime..."
        
        Get-MymobilityPodLogs
        
        Write-Host "Collection complete. Sleeping for 60 minutes..."
        
        # Sleep in shorter intervals to check the continue flag more frequently
        $sleepUntil = (Get-Date).AddSeconds(3600)  
        while ((Get-Date) -lt $sleepUntil -and $global:continue) {
            Start-Sleep -Seconds 1
        }
    }
}
catch {
    Write-Host "`nUnexpected error: $($_.Exception.Message)"
}
finally {
    # Always run the cleanup procedure
    Exit-LogCollector
}
