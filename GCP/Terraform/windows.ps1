param (
    [string]$secret_project_id,
    [string]$secret_name
)

$access_headers = @{
    "Metadata-Flavor" = "Google"
}
$access_token = $(Invoke-RestMethod -Headers $access_headers -Method 'Get' -Uri "http://metadata/computeMetadata/v1/instance/service-accounts/default/token").access_token

$secret_headers = @{
    "authorization" = "Bearer $access_token"
}

$secret_json = $(Invoke-RestMethod -Headers $secret_headers -Method 'Get' -Uri "https://secretmanager.googleapis.com/v1/projects/$secret_project_id/secrets/$secret_name/versions/latest:access").payload.data
$secret_json = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secret_json)) | ConvertFrom-Json

$Url = $secret_json.PCC_URL
$username = $secret_json.PCC_USER
$password = $secret_json.PCC_PASS
$console_name = $secret_json.PCC_SAN

$Body = @{
    username = $username
    password = $password
}
$token = (Invoke-RestMethod -Method 'Post' -Uri "$Url/api/v1/authenticate" -Body ($Body | ConvertTo-Json) -ContentType 'application/json').token
$parameters = @{ 
    Uri = "$Url/api/v1/scripts/defender.ps1"
    Method = "Post"
    Headers = @{
        "authorization" = "Bearer $token" 
    } 
    OutFile = "defender.ps1" 
}
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
Invoke-WebRequest @parameters
.\defender.ps1 -type $defenderType -consoleCN $console_name -install -u