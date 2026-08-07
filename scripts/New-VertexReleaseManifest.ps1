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

$assetRoot = (Resolve-Path -LiteralPath $AssetDirectory).Path

function Get-XrigAssetMetadata([string]$Id, [string]$FileName, [string]$Version, [string]$Verification) {
    $path = Join-Path $assetRoot $FileName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Vertex release asset is missing: $FileName" }
    $metadata = [ordered]@{
        id = $Id
        path = $FileName
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        size_bytes = [string](Get-Item -LiteralPath $path).Length
        verification = $Verification
        version = $Version
    }
    if ($Verification -eq 'detached-ed25519') {
        $signature = "$path.sig"
        if (-not (Test-Path -LiteralPath $signature -PathType Leaf)) { throw "Required Vertex release signature is missing: $FileName.sig" }
        $metadata.sig_path = "$FileName.sig"
    }
    return $metadata
}

$assets = @(
    (Get-XrigAssetMetadata 'windows.amd64.app' "Vertex-$VertexVersion-win-x64.exe" $VertexVersion 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.cudart' 'cudart-llama-bin-win-cuda-12.4-x64.zip' 'b9878' 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.factory_config' 'gemma4-12b-5060ti.json' $VertexVersion 'manifest'),
    (Get-XrigAssetMetadata 'windows.amd64.install' "Vertex-install-$VertexVersion-win-x64.exe" $VertexVersion 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.llama_cuda' 'llama-b9878-bin-win-cuda-12.4-x64.zip' 'b9878' 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.llama_openvino' 'llama-b9999-bin-win-openvino-2026.2.1-x64.zip' 'b9999' 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.llama_vulkan' 'llama-b9999-bin-win-vulkan-x64.zip' 'b9999' 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.package' "Vertex-runtime-$VertexVersion-win-x64.tar.gz" $VertexVersion 'detached-ed25519'),
    (Get-XrigAssetMetadata 'windows.amd64.vertex_installer' "Install-Vertex-inner-$VertexVersion.ps1" $VertexVersion 'detached-ed25519')
)

$values = @{
    architecture = 'amd64'
    base_url = "https://github.com/xrigpc/xrig-releases/releases/download/$ReleaseTag"
    channel = $Channel
    cuda_runtime_version = '12.4'
    electron_version = '40.10.2'
    format = 'xrig-release-v1'
    gpu_profile = 'windows-nvidia-rtx-5060-ti-16gb-cuda'
    kai_version = $KaiCompatibilityVersion
    llama_cpp_version = 'b9878'
    nvidia_driver_min = '551.61'
    platform_version = $PlatformVersion
    python_version = '3.12.10'
    version = $ReleaseTag.Substring(1)
    vertex_version = $VertexVersion
    windows_min_build = '22621'
}
foreach ($asset in $assets) {
    $prefix = "asset.$($asset.id)"
    $values["$prefix.path"] = $asset.path
    $values["$prefix.sha256"] = $asset.sha256
    if ($asset.verification -eq 'detached-ed25519') { $values["$prefix.sig_path"] = $asset.sig_path }
    $values["$prefix.size_bytes"] = $asset.size_bytes
    $values["$prefix.verification"] = $asset.verification
    $values["$prefix.version"] = $asset.version
}

$keys = [string[]]@($values.Keys)
[Array]::Sort($keys, [StringComparer]::Ordinal)
$lines = foreach ($key in $keys) { "$key=$($values[$key])" }
$directory = Split-Path -Parent $OutputPath
if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), (($lines -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
