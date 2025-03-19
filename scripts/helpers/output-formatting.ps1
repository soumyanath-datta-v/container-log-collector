# Output formatting functions for log entries

function Format-LogEntry {
    param (
        [string]$podName,
        [string]$logContent,
        [datetime]$timestamp
    )
    return "$($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) - Logs from pod: $podName`n$logContent`n"
}

function Format-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Format-ErrorEntry {
    param (
        [string]$podName,
        [string]$errorMessage,
        [datetime]$timestamp
    )
    return "$($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) - Error retrieving logs from pod: $podName - $errorMessage`n"
}