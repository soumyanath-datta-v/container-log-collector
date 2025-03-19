# Helper functions for executing kubectl commands

function Get-MymobilityPods {
    param (
        [string]$namespace = "prod"
    )
    $podsOutput = kubectl get pods -n $namespace | Select-String 'mymobility'
    return $podsOutput
}

function Filter-Pods {
    param (
        [array]$pods
    )
    $filteredPods = @()
    foreach ($podLine in $pods) {
        $podName = ($podLine -split '\s+')[0]
        if ($podName -notmatch "mymobility-apps" -and $podName -notmatch "mymobility-platform-api") {
            $filteredPods += $podName
        }
    }
    return $filteredPods
}

function Get-PodLogs {
    param (
        [string]$podName,
        [string]$namespace = "prod"
    )
    try {
        $podLogs = kubectl exec -it $podName -n $namespace -- cat app-state.log 2>&1
        return $podLogs
    }
    catch {
        return "Exception retrieving logs from $podName`: $_"
    }
}
