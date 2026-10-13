#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("xrig-vertex-manifest-test-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $temporary | Out-Null
try {
    $signed = @(
        'xrig-vertex_1.1.0-rc.1_amd64.deb',
        'xrig-app-windows-amd64.exe',
        'xrig-runtime-windows-amd64.exe',
        'xrig-stack-helper-windows-amd64.exe',
        'vertex-configure-windows-amd64.exe',
        'Install-Vertex-1.1.0-rc.1.ps1'
    )
    foreach ($name in $signed) {
        [IO.File]::WriteAllBytes((Join-Path $temporary $name), [byte[]](0x4d, 0x5a, 0x90, 0x00))
        [IO.File]::WriteAllText((Join-Path $temporary "$name.sig"), 'test-signature', [Text.UTF8Encoding]::new($false))
    }
    $generator = Join-Path $PSScriptRoot 'New-VertexReleaseManifest.ps1'
    $manifest = Join-Path $temporary 'xrig-release-v1.manifest'
    & $generator -ReleaseTag v1.1.0-rc.1 -PlatformVersion 1.0.2-rc.4 -VertexVersion 1.1.0-rc.1 -KaiCompatibilityVersion 1.0.2-rc.1 `
        -AssetDirectory $temporary -OutputPath $manifest -Channel candidate
    $content = [IO.File]::ReadAllText($manifest, [Text.UTF8Encoding]::new($false))
    if ($content.Contains("`r")) { throw 'Manifest must use LF line endings.' }
    $keys = @($content.Trim().Split("`n") | ForEach-Object { ($_ -split '=', 2)[0] })
    $ordered = [string[]]$keys.Clone(); [Array]::Sort($ordered, [StringComparer]::Ordinal)
    if (($keys -join "`n") -ne ($ordered -join "`n")) { throw 'Manifest keys are not in canonical lexical order.' }
    $headers = @($keys | Where-Object { -not $_.StartsWith('asset.') })
    if ($headers.Count -ne 15) { throw "Manifest must carry exactly the 15 Platform headers, found $($headers.Count)." }
    $assetIds = @($keys | Where-Object { $_.StartsWith('asset.') } | ForEach-Object { $_ -replace '^asset\.(.+)\.[a-z0-9_]+$', '$1' } | Sort-Object -Unique)
    $expectedIds = @('linux.amd64.deb', 'windows.amd64.vertex_app', 'windows.amd64.vertex_configure', 'windows.amd64.vertex_installer', 'windows.amd64.vertex_runtime', 'windows.amd64.vertex_stack_helper')
    if (($assetIds -join ',') -ne ($expectedIds -join ',')) { throw "Unexpected manifest asset ids: $($assetIds -join ', ')" }
    if (@($keys | Where-Object { $_.StartsWith('asset.') }).Count -ne 36) { throw 'Every asset must carry path, sha256, sig_path, size_bytes, verification and version.' }
    foreach ($line in @(
        'base_url=https://github.com/xrigpc/xrig-releases/releases/download/v1.1.0-rc.1',
        'channel=candidate',
        'format=xrig-release-v1',
        'gpu_profile=cross-platform-vertex',
        'version=1.1.0-rc.1',
        'vertex_version=1.1.0-rc.1',
        'platform_version=1.0.2-rc.4',
        'kai_version=1.0.2-rc.1',
        'asset.linux.amd64.deb.path=xrig-vertex_1.1.0-rc.1_amd64.deb',
        'asset.linux.amd64.deb.sig_path=xrig-vertex_1.1.0-rc.1_amd64.deb.sig',
        'asset.windows.amd64.vertex_installer.path=Install-Vertex-1.1.0-rc.1.ps1',
        'asset.windows.amd64.vertex_app.sha256=9f2981a7cc4d40a2a409dc895de64253acd819d7c0011c8e80b86fe899464e31',
        'asset.windows.amd64.vertex_app.size_bytes=4',
        'asset.windows.amd64.vertex_stack_helper.verification=detached-ed25519',
        'asset.windows.amd64.vertex_configure.version=1.1.0-rc.1'
    )) {
        if ($content -notmatch "(?m)^$([Regex]::Escape($line))$") { throw "Missing manifest line: $line" }
    }
    if ($content -match '(?m)^asset\.[^=]*\.verification=(?!detached-ed25519$)') { throw 'Every Vertex asset must be detached-ed25519 signed.' }
    if ($content -match 'asset\.windows\.amd64\.(kai|identity|llama|cudart|factory_config|app\.|install\.|package)') { throw 'Vertex-only manifest must not carry Kai, Platform, runtime archive or legacy payloads.' }

    $rejected = $false
    try {
        & $generator -ReleaseTag v1.1.0 -PlatformVersion 1.0.2-rc.4 -VertexVersion 1.1.0-rc.1 -KaiCompatibilityVersion 1.0.2-rc.1 `
            -AssetDirectory $temporary -OutputPath (Join-Path $temporary 'mismatch.manifest') -Channel candidate
    } catch { $rejected = $true }
    if (-not $rejected) { throw 'A release tag that differs from the Vertex version must be rejected.' }

    Remove-Item -LiteralPath (Join-Path $temporary 'xrig-vertex_1.1.0-rc.1_amd64.deb.sig')
    $rejected = $false
    try {
        & $generator -ReleaseTag v1.1.0-rc.1 -PlatformVersion 1.0.2-rc.4 -VertexVersion 1.1.0-rc.1 -KaiCompatibilityVersion 1.0.2-rc.1 `
            -AssetDirectory $temporary -OutputPath (Join-Path $temporary 'unsigned.manifest') -Channel candidate
    } catch { $rejected = $true }
    if (-not $rejected) { throw 'An asset without a detached signature must be rejected.' }
}
finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Vertex-only release manifest contract passed.'
