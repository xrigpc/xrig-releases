#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$ReleaseTag,
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$PlatformVersion,
    # Vertex is a compatibility requirement for Kai; it is not rebuilt or
    # republished as part of this product-scoped release.
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$VertexVersion,
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$KaiVersion,
    [Parameter(Mandatory = $true)] [string]$AssetDirectory,
    [Parameter(Mandatory = $true)] [string]$OutputPath,
    [ValidateSet('candidate', 'stable')] [string]$Channel = 'stable'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$assetRoot = (Resolve-Path -LiteralPath $AssetDirectory).Path
$packageName = "Kai-$KaiVersion-win-x64.exe"
$packagePath = Join-Path $assetRoot $packageName
$signaturePath = "$packagePath.sig"
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { throw "Required Kai package is missing: $packageName" }
if (-not (Test-Path -LiteralPath $signaturePath -PathType Leaf)) { throw "Required Kai package signature is missing: $packageName.sig" }

$values = @{
    architecture = 'amd64'
    base_url = "https://github.com/xrigpc/xrig-releases/releases/download/$ReleaseTag"
    channel = $Channel
    cuda_runtime_version = '12.4'
    electron_version = '40.10.2'
    format = 'xrig-release-v1'
    gpu_profile = 'windows-nvidia-rtx-5060-ti-16gb-cuda'
    kai_version = $KaiVersion
    llama_cpp_version = 'b9878'
    nvidia_driver_min = '551.61'
    platform_version = $PlatformVersion
    python_version = '3.12.10'
    version = $ReleaseTag.Substring(1)
    vertex_version = $VertexVersion
    windows_min_build = '22621'
    'asset.windows.amd64.kai.path' = $packageName
    'asset.windows.amd64.kai.sha256' = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    'asset.windows.amd64.kai.sig_path' = "$packageName.sig"
    'asset.windows.amd64.kai.size_bytes' = [string](Get-Item -LiteralPath $packagePath).Length
    'asset.windows.amd64.kai.verification' = 'detached-ed25519'
    'asset.windows.amd64.kai.version' = $KaiVersion
}

$keys = [string[]]@($values.Keys)
[Array]::Sort($keys, [StringComparer]::Ordinal)
$lines = foreach ($key in $keys) { "$key=$($values[$key])" }
$directory = Split-Path -Parent $OutputPath
if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), (($lines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
