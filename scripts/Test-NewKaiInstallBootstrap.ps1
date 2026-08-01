#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$temporary = Join-Path ([IO.Path]::GetTempPath()) ("xrig-kai-bootstrap-test-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $temporary | Out-Null
try {
    $output = Join-Path $temporary 'Install-Kai.ps1'
    & (Join-Path $PSScriptRoot 'New-KaiInstallBootstrap.ps1') -ReleaseTag v1.0.2-rc.1 -KaiVersion 1.0.2-rc.1 -Channel candidate -OutputPath $output
    $content = Get-Content -LiteralPath $output -Raw

    foreach ($required in @(
        'C:\Program Files',
        'xrig-identity.exe',
        "'--mode', 'verify', '--json'",
        "'--mode', 'check-online', '--json'",
        "'--mode', 'verify-release'",
        "'--mode', 'verify-artifact'",
        "'--mode', 'check-release-floor'",
        "'--mode', 'record-release-floor'",
        'https://github.com/xrigpc/xrig-releases/releases/download/$ReleaseTag',
        '$ExpectedKaiVersion = ''1.0.2-rc.1''',
        '$ExpectedChannel = ''candidate''',
        'Start-Process -FilePath $package -ArgumentList ''/S''',
        'github-releases.githubusercontent.com'
    )) {
        if (-not $content.Contains($required)) { throw "Bootstrap contract is missing: $required" }
    }
    foreach ($forbidden in @('$PSScriptRoot', 'Get-AuthenticodeSignature', 'ReleaseManifestUrl', 'ReleaseManifestSha256', 'Pallav0099')) {
        if ($content.Contains($forbidden)) { throw "Bootstrap must not depend on: $forbidden" }
    }
    $firstDownload = $content.IndexOf('Get-XrigDownload "$ReleaseRoot')
    if ($firstDownload -lt 0) { throw 'Bootstrap must download a versioned release manifest.' }
    if ($content.IndexOf("'--mode', 'verify', '--json'") -gt $firstDownload) {
        throw 'Bootstrap must verify local Platform identity before any release download.'
    }
    if ($content.IndexOf("'--mode', 'check-online', '--json'") -gt $firstDownload) {
        throw 'Bootstrap must verify the active XRIG device before any release download.'
    }
    if ($content -notmatch '\$hosts = @\(') { throw 'Bootstrap must restrict release download hosts.' }
    if ($content -notmatch '\$release\.channel -ne \$ExpectedChannel') { throw 'Bootstrap must bind to its generated XRIG release channel.' }
}
finally { Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Kai public installer bootstrap contract passed.'
