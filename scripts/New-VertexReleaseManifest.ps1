#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$ReleaseTag,
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$PlatformVersion,
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$VertexVersion,
    # The shared release format records the compatible Kai version. Vertex does
    # not package, install, or otherwise depend on Kai in this release profile.
    [Parameter(Mandatory = $true)] [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$')] [string]$KaiCompatibilityVersion,
    [Parameter(Mandatory = $true)] [string]$AssetDirectory,
    [Parameter(Mandatory = $true)] [string]$OutputPath,
    [ValidateSet('candidate', 'stable')] [string]$Channel = 'stable'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Vertex's app-only release contract (xrig-llama-backend
# scripts/sign-release-manifest.sh): one release version, and every payload is
# a Vertex binary of that version. Runtime stacks and models are versioned and
# signed independently, so no llama.cpp or CUDA archive ships here.
if ($ReleaseTag -ne "v$VertexVersion") { throw 'ReleaseTag must be v<VertexVersion> for the single-product Vertex channel.' }

$assetRoot = (Resolve-Path -LiteralPath $AssetDirectory).Path

function Get-XrigAssetMetadata([string]$Id, [string]$FileName) {
    $path = Join-Path $assetRoot $FileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Vertex release asset is missing: $FileName" }
    if (-not (Test-Path -LiteralPath "$path.sig" -PathType Leaf)) { throw "Required Vertex release signature is missing: $FileName.sig" }
    return [ordered]@{
        id = $Id
        path = $FileName
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        sig_path = "$FileName.sig"
        size_bytes = [string](Get-Item -LiteralPath $path).Length
        verification = 'detached-ed25519'
        version = $VertexVersion
    }
}

$assets = @(
    (Get-XrigAssetMetadata 'linux.amd64.deb' "xrig-vertex_$($VertexVersion)_amd64.deb"),
    (Get-XrigAssetMetadata 'windows.amd64.vertex_app' 'xrig-app-windows-amd64.exe'),
    (Get-XrigAssetMetadata 'windows.amd64.vertex_configure' 'vertex-configure-windows-amd64.exe'),
    (Get-XrigAssetMetadata 'windows.amd64.vertex_installer' "Install-Vertex-$VertexVersion.ps1"),
    (Get-XrigAssetMetadata 'windows.amd64.vertex_runtime' 'xrig-runtime-windows-amd64.exe'),
    (Get-XrigAssetMetadata 'windows.amd64.vertex_stack_helper' 'xrig-stack-helper-windows-amd64.exe')
)

# XRIG Platform's release parser still requires these historical headers. They
# are compatibility metadata only; the signed stack descriptors own every real
# runtime and dependency pin.
$values = @{
    architecture = 'amd64'
    base_url = "https://github.com/xrigpc/xrig-releases/releases/download/$ReleaseTag"
    channel = $Channel
    cuda_runtime_version = '12.4'
    electron_version = '40.10.2'
    format = 'xrig-release-v1'
    gpu_profile = 'cross-platform-vertex'
    kai_version = $KaiCompatibilityVersion
    llama_cpp_version = 'b9878'
    nvidia_driver_min = '551.61'
    platform_version = $PlatformVersion
    python_version = '3.11.9'
    version = $VertexVersion
    vertex_version = $VertexVersion
    windows_min_build = '22621'
}
foreach ($asset in $assets) {
    $prefix = "asset.$($asset.id)"
    foreach ($field in @('path', 'sha256', 'sig_path', 'size_bytes', 'verification', 'version')) { $values["$prefix.$field"] = $asset[$field] }
}

$keys = [string[]]@($values.Keys)
[Array]::Sort($keys, [StringComparer]::Ordinal)
$lines = foreach ($key in $keys) { "$key=$($values[$key])" }
$directory = Split-Path -Parent $OutputPath
if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), (($lines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
