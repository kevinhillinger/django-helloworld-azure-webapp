

function zipFiles($zipFileName, $folderPath) {
   Add-Type -Assembly System.IO.Compression.FileSystem

   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   $includeBaseDir = $false

   if ((Test-Path -Path $zipFileName) -eq $true) {
        Remove-Item $zipFileName
   }
   [System.IO.Compression.ZipFile]::CreateFromDirectory($folderPath, "$PSScriptRoot\$zipFileName", $compressionLevel, $includeBaseDir)
}

function getPublishProfile() {
    [xml]$settings = Get-Content -Path '.\site.PublishSettings'
    $profile = $settings.publishData.publishProfile | where { $_.publishMethod -eq "MSDeploy" }

    return $profile
}


function getHttpHeaders($username, $password) {
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))

    $authHeader = "Basic {0}" -f $base64AuthInfo
    $headers = @{'Authorization'=$authHeader; }

    return $headers
}

function putZipFile($siteName, $zipFileName, $headers) {
    $apiUrl = "https://$siteName.scm.azurewebsites.net/api/zip/site/wwwroot"
	$result = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method PUT -InFile ".\$zipFileName"
    $result | Out-File -FilePath '.\log.txt' -Append:$true
}

function installRequirements($siteName, $headers) {
    $apiUrl = "https://$siteName.scm.azurewebsites.net/api/command"

	$command = @"
    {
		"command": "azure-requirements.bat",
		"dir": ".\\site\\wwwroot"
	}
"@	
	$result = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Body $command -ContentType "application/json" -Method POST
	$result | Out-File -FilePath '.\log.txt' -Append:$true
}

function Deploy-WebApp() {

    Write-Output "Creating zip"
    $zipFileName = "azure-webapp.zip"
    zipFiles -zipFileName $zipFileName -folderPath "$PSScriptRoot\..\src"

    $publishProfile = getPublishProfile

    $siteName = $publishProfile.msDeploySite
    $headers = getHttpHeaders -username $publishProfile.userName -password $publishProfile.userPWD

    Write-Output "Deploying to Azure App Services"
    putZipFile -siteName $siteName -zipFileName $zipFileName -headers $headers

    Write-Output "Installing Python requirements in Azure App Services..."
    installRequirements -siteName $siteName -headers $headers
}

Deploy-WebApp
