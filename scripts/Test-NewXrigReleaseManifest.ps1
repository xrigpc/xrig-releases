#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("xrig-kai-manifest-test-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $temporary | Out-Null
try {
    $package = Join-Path $temporary 'Kai-1.0.2-rc.1-win-x64.exe'
    [IO.File]::WriteAllBytes($package, [byte[]](0x4d, 0x5a, 0x90, 0x00))
    [IO.File]::WriteAllText("$package.sig", 'test-signature', [Text.UTF8Encoding]::new($false))
    $manifest = Join-Path $temporary 'xrig-release-v1.manifest'
    & (Join-Path $PSScriptRoot 'New-XrigReleaseManifest.ps1') `
        -ReleaseTag v1.0.2-rc.1 -PlatformVersion 1.0.1-rc.4 -VertexVersion 1.0.1-rc.4 -KaiVersion 1.0.2-rc.1 `
        -AssetDirectory $temporary -OutputPath $manifest -Channel candidate

    $content = [IO.File]::ReadAllText($manifest, [Text.UTF8Encoding]::new($false))
    if ($content.Contains("`r")) { throw 'Manifest must use LF line endings.' }
    $keys = @($content.Trim().Split("`n") | ForEach-Object { ($_ -split '=', 2)[0] })
    $ordered = [string[]]$keys.Clone(); [Array]::Sort($ordered, [StringComparer]::Ordinal)
    if (($keys -join "`n") -ne ($ordered -join "`n")) { throw 'Manifest keys are not in canonical lexical order.' }
    foreach ($line in @(
        'base_url=https://github.com/xrigpc/xrig-releases/releases/download/v1.0.2-rc.1',
        'python_version=3.12.10',
        'asset.windows.amd64.kai.path=Kai-1.0.2-rc.1-win-x64.exe',
        'asset.windows.amd64.kai.sig_path=Kai-1.0.2-rc.1-win-x64.exe.sig',
        'asset.windows.amd64.kai.verification=detached-ed25519'
    )) {
        if ($content -notmatch "(?m)^$([Regex]::Escape($line))$") { throw "Missing manifest line: $line" }
    }
    if ($content -match 'asset\.windows\.amd64\.(vertex|identity|llama|factory_config)') {
        throw 'Kai-only manifest must not carry Vertex or Platform release artifacts.'
    }
}
finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Kai-only release manifest contract passed.'
