#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("xrig-vertex-manifest-test-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $temporary | Out-Null
try {
    $signed = @(
        'Vertex-1.0.2-rc.1-win-x64.exe',
        'Vertex-install-1.0.2-rc.1-win-x64.exe',
        'Vertex-runtime-1.0.2-rc.1-win-x64.tar.gz',
        'Install-Vertex-inner-1.0.2-rc.1.ps1',
        'llama-b9878-bin-win-cuda-12.4-x64.zip',
        'cudart-llama-bin-win-cuda-12.4-x64.zip',
        'llama-b9999-bin-win-vulkan-x64.zip',
        'llama-b9999-bin-win-openvino-2026.2.1-x64.zip'
    )
    foreach ($name in $signed) {
        [IO.File]::WriteAllBytes((Join-Path $temporary $name), [byte[]](0x4d, 0x5a, 0x90, 0x00))
        [IO.File]::WriteAllText((Join-Path $temporary "$name.sig"), 'test-signature', [Text.UTF8Encoding]::new($false))
    }
    [IO.File]::WriteAllText((Join-Path $temporary 'gemma4-12b-5060ti.json'), '{"model":{"alias":"gemma-4-12b-it"}}', [Text.UTF8Encoding]::new($false))
    $manifest = Join-Path $temporary 'xrig-release-v1.manifest'
    & (Join-Path $PSScriptRoot 'New-VertexReleaseManifest.ps1') `
        -ReleaseTag v1.0.2-rc.1 -PlatformVersion 1.0.1-rc.4 -VertexVersion 1.0.2-rc.1 -KaiCompatibilityVersion 1.0.2-rc.1 `
        -AssetDirectory $temporary -OutputPath $manifest -Channel candidate
    $content = [IO.File]::ReadAllText($manifest, [Text.UTF8Encoding]::new($false))
    if ($content.Contains("`r")) { throw 'Manifest must use LF line endings.' }
    $keys = @($content.Trim().Split("`n") | ForEach-Object { ($_ -split '=', 2)[0] })
    $ordered = [string[]]$keys.Clone(); [Array]::Sort($ordered, [StringComparer]::Ordinal)
    if (($keys -join "`n") -ne ($ordered -join "`n")) { throw 'Manifest keys are not in canonical lexical order.' }
    foreach ($line in @(
        'base_url=https://github.com/xrigpc/xrig-releases/releases/download/v1.0.2-rc.1',
        'asset.windows.amd64.app.path=Vertex-1.0.2-rc.1-win-x64.exe',
        'asset.windows.amd64.vertex_installer.path=Install-Vertex-inner-1.0.2-rc.1.ps1',
        'asset.windows.amd64.factory_config.verification=manifest',
        'asset.windows.amd64.llama_vulkan.verification=detached-ed25519',
        'asset.windows.amd64.llama_openvino.verification=detached-ed25519'
    )) {
        if ($content -notmatch "(?m)^$([Regex]::Escape($line))$") { throw "Missing manifest line: $line" }
    }
    if ($content -match 'asset\.windows\.amd64\.(kai|identity)') { throw 'Vertex-only manifest must not carry Kai or Platform payloads.' }
}
finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Vertex-only release manifest contract passed.'
