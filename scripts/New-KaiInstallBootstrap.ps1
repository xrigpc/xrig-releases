#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$ReleaseTag,
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$KaiVersion,
    [Parameter(Mandatory = $true)] [ValidateSet('candidate', 'stable')] [string]$Channel,
    [Parameter(Mandatory = $true)] [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$template = @'
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$ReleaseTag = '__RELEASE_TAG__'
$ExpectedKaiVersion = '__KAI_VERSION__'
$ExpectedChannel = '__CHANNEL__'
$ReleaseRoot = "https://github.com/xrigpc/xrig-releases/releases/download/$ReleaseTag"
$ProgramFilesRoot = if ($env:ProgramW6432) { $env:ProgramW6432 } elseif ($env:ProgramFiles) { $env:ProgramFiles } else { 'C:\Program Files' }
$IdentityPath = Join-Path $ProgramFilesRoot 'XRIG\bin\xrig-identity.exe'

function Stop-KaiInstall([string]$Message) {
    Write-Host $Message
    exit 1
}

function Assert-ApprovedUri([string]$Value) {
    try { $uri = [Uri]$Value } catch { Stop-KaiInstall 'Kai installer received an invalid XRIG release URL.' }
    $hosts = @('github.com', 'github-releases.githubusercontent.com', 'release-assets.githubusercontent.com', 'objects.githubusercontent.com')
    if ($uri.Scheme -ne 'https' -or $uri.UserInfo -or $hosts -notcontains $uri.Host.ToLowerInvariant()) {
        Stop-KaiInstall 'Kai installer rejected an unapproved XRIG release URL.'
    }
    return $uri
}

function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Get-XrigDownload([string]$Url, [string]$Destination) {
    $partial = "$Destination.partial"
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    try {
        $uri = Assert-ApprovedUri $Url
        for ($hop = 0; $hop -lt 5; $hop++) {
            $response = $client.GetAsync($uri, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
            try {
                if ([int]$response.StatusCode -ge 300 -and [int]$response.StatusCode -lt 400) {
                    if (-not $response.Headers.Location) { Stop-KaiInstall 'Kai installer received an invalid XRIG release redirect.' }
                    $uri = Assert-ApprovedUri ([Uri]::new($uri, $response.Headers.Location).AbsoluteUri)
                    continue
                }
                if (-not $response.IsSuccessStatusCode) { Stop-KaiInstall "Kai installer could not download the XRIG release (HTTP $([int]$response.StatusCode))." }
                $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $file = [IO.File]::Open($partial, [IO.FileMode]::Create, [IO.FileAccess]::Write)
                try { $stream.CopyTo($file) } finally { $file.Dispose(); $stream.Dispose() }
                Move-Item -LiteralPath $partial -Destination $Destination -Force
                return
            } finally { $response.Dispose() }
        }
        Stop-KaiInstall 'Kai installer reached too many XRIG release redirects.'
    } finally {
        $client.Dispose()
        $handler.Dispose()
    }
}

function Invoke-XrigIdentity([string[]]$Arguments, [string]$Failure) {
    $output = & $IdentityPath @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { Stop-KaiInstall $Failure }
    return (($output -join "`n") | ConvertFrom-Json -ErrorAction Stop)
}

try {
    if (-not (Test-Path -LiteralPath $IdentityPath -PathType Leaf)) {
        Stop-KaiInstall 'XRIG Platform was not found. Register, activate, or reactivate this XRIG AI PC before installing Kai.'
    }
    $local = Invoke-XrigIdentity @('--mode', 'verify', '--json') 'Kai requires an active XRIG Platform identity. Activate or repair this XRIG AI PC, then run the Kai installer again.'
    if (-not $local.valid) { Stop-KaiInstall 'Kai requires an active XRIG Platform identity. Activate or repair this XRIG AI PC, then run the Kai installer again.' }
    $online = Invoke-XrigIdentity @('--mode', 'check-online', '--json') 'This PC is not registered as an active XRIG AI PC. Run XRIG activation or contact XRIG support.'
    if (-not $online.valid) { Stop-KaiInstall 'This PC is not registered as an active XRIG AI PC. Run XRIG activation or contact XRIG support.' }

    Add-Type -AssemblyName System.Net.Http
    $cache = Join-Path $env:LOCALAPPDATA "XRIG\Kai\installer-cache\$ReleaseTag"
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $manifest = Join-Path $cache 'xrig-release-v1.manifest'
    $manifestSignature = "$manifest.sig"
    Get-XrigDownload "$ReleaseRoot/xrig-release-v1.manifest" $manifest
    Get-XrigDownload "$ReleaseRoot/xrig-release-v1.manifest.sig" $manifestSignature
    $release = Invoke-XrigIdentity @('--mode', 'verify-release', '--manifest', $manifest, '--signature', $manifestSignature, '--json') 'Kai installer rejected the signed XRIG release manifest.'
    if ($release.kai_version -ne $ExpectedKaiVersion -or $release.version -ne $ReleaseTag.Substring(1)) { Stop-KaiInstall 'Kai installer rejected a release for a different Kai version.' }
    if ($release.channel -ne $ExpectedChannel) { Stop-KaiInstall 'Kai installer rejected a release from the wrong XRIG channel.' }
    $asset = $release.artifacts.'windows.amd64.kai'
    if (-not $asset -or $asset.version -ne $ExpectedKaiVersion -or $asset.verification -ne 'detached-ed25519') { Stop-KaiInstall 'Kai installer rejected the XRIG Kai package declaration.' }
    if ($asset.url -notlike "$ReleaseRoot/*" -or $asset.signature_url -notlike "$ReleaseRoot/*") { Stop-KaiInstall 'Kai installer rejected a non-versioned XRIG Kai package URL.' }

    $package = Join-Path $cache $asset.path
    $packageSignature = Join-Path $cache $asset.signature_path
    Get-XrigDownload $asset.url $package
    Get-XrigDownload $asset.signature_url $packageSignature
    if ((Get-Item -LiteralPath $package).Length -ne [int64]$asset.size -or (Get-Sha256 $package) -ne $asset.sha256) { Stop-KaiInstall 'Kai installer rejected a Kai package whose size or SHA-256 did not match.' }
    Invoke-XrigIdentity @('--mode', 'verify-artifact', '--file', $package, '--signature', $packageSignature, '--sha256', $asset.sha256, '--json') 'Kai installer rejected the XRIG signature on the Kai package.' | Out-Null
    Invoke-XrigIdentity @('--mode', 'check-release-floor', '--product', 'kai', '--version', $ExpectedKaiVersion, '--json') 'Kai installer rejected a downgrade attempt.' | Out-Null

    $process = Start-Process -FilePath $package -ArgumentList '/S' -Wait -PassThru
    if ($process.ExitCode -ne 0) { Stop-KaiInstall 'Kai setup did not complete. Run the installer again or open XRIG diagnostics.' }
    Invoke-XrigIdentity @('--mode', 'record-release-floor', '--product', 'kai', '--version', $ExpectedKaiVersion, '--json') 'Kai installed, but XRIG could not record its local release floor.' | Out-Null
    Write-Host "Kai $ExpectedKaiVersion is installed. Start Kai from the Start menu."
} catch {
    Stop-KaiInstall 'Kai installation could not complete. Check your XRIG Platform identity and internet connection, then run the installer again.'
}
'@

$script = $template.Replace('__RELEASE_TAG__', $ReleaseTag).Replace('__KAI_VERSION__', $KaiVersion).Replace('__CHANNEL__', $Channel)
$directory = Split-Path -Parent $OutputPath
if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $script, [Text.UTF8Encoding]::new($false))
