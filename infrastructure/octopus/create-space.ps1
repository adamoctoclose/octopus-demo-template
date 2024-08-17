param(
    [Parameter(Mandatory = $True)]
    [string]$OctopusURL,
    [Parameter(Mandatory = $True)]
    [string]$OctopusAPIKey,
    [Parameter(Mandatory = $True)]
    [string]$SpaceName,
    [Parameter(Mandatory = $False)]
    [string]$Description,
    [Parameter(Mandatory = $False)]
    [string[]]$ManagersTeams,
    [Parameter(Mandatory = $False)]
    [string[]]$ManagerTeamMembers,
    [Parameter(Mandatory = $False)]
    [string[]]$Environments
)

$ErrorActionPreference = "Stop";

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }


$body = @{
    Name                     = $spaceName
    Description              = $description
    SpaceManagersTeams       = $managersTeams
    SpaceManagersTeamMembers = $managerTeamMembers
    IsDefault                = $false
    TaskQueueStopped         = $false
} | ConvertTo-Json

$response = try {
    Write-Host "Creating space '$spaceName'"
    Write-Host "URL: '$octopusURL'"
    (Invoke-WebRequest $octopusURL/api/spaces -Headers $header -Method Post -Body $body -ErrorVariable octoError)
}
catch [System.Net.WebException] {
    $_.Exception.Response
}

if ($octoError) {
    Write-Host "An error was encountered trying to create the space: $($octoError.Message)"
    exit
}

$space = $response.Content | ConvertFrom-Json

foreach ($environment in $environments) {
    $body = @{
        Name = $environment
    } | ConvertTo-Json

    Write-Host "Creating environment '$environment'"
    $response = try {
        (Invoke-WebRequest "$octopusURL/api/$($space.Id)/environments" -Headers $header -Method Post -Body $body -ErrorVariable octoError)
    }
    catch [System.Net.WebException] {
        $_.Exception.Response
    }

    if ($octoError) {
        Write-Host "An error was encountered trying to create the environment: $($octoError.Message)"
        exit
    }
}


$body = @{
    Name                     = $spaceName
    Description              = $description
    SpaceManagersTeams       = $managersTeams
    SpaceManagersTeamMembers = $managerTeamMembers
    IsDefault                = $false
    TaskQueueStopped         = $false
} | ConvertTo-Json

$response = try {
    Write-Host "Creating space '$spaceName'"
    Write-Host "URL: '$octopusURL'"
    (Invoke-WebRequest $octopusURL/api/spaces -Headers $header -Method Post -Body $body -ErrorVariable octoError)
}
catch [System.Net.WebException] {
    $_.Exception.Response
}

Invoke-WebRequest -UseBasicParsing -Uri "https://adamclose.octopus.app/api/Spaces-244/git-credentials" `
    -Method "POST" `
    -ContentType "application/json" `
    -Body "{`"Id`":null,`"SpaceId`":`"`",`"Name`":`"adamoctoclose`",`"Description`":`"`",`"Details`":{`"Type`":`"UsernamePassword`",`"Username`":`"adamoctoclose`",`"Password`":{`"HasValue`":true,`"NewValue`":`"wfwrgerwgregregregrgr`"}},`"Links`":null}"