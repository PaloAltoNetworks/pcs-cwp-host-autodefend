param (
    [string]$token,
    [string]$PCC_URL,
    [string]$PCC_SAN
)

#Parameters to download the defender script
$parameters = @{ 
    Uri = "$PCC_URL/api/v1/scripts/defender.ps1"
    Method = "Post"
    Headers = @{
        "authorization" = "Bearer $token" 
    } 
    OutFile = "defender.ps1" 
}

#Set type of defender based on the requirements
$defenderType = "serverWindows"
try {
    docker ps
    $defenderType = "dockerWindows"
} catch {
    echo "Docker is not running"
    try {
    ctr c ls
    $defenderType = "containerdWindows"
    } catch {
    echo "Containerd is not running"
    }
}

#Download and Install defender
Invoke-WebRequest @parameters
.\defender.ps1 -type $defenderType -consoleCN $PCC_SAN -install -u