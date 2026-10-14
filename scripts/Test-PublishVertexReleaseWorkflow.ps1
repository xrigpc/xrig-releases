[CmdletBinding()]
param([string]$WorkflowPath = '')

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($WorkflowPath)) { $WorkflowPath = Join-Path $PSScriptRoot '..\.github\workflows\publish-vertex-release.yml' }
$content = Get-Content -LiteralPath (Resolve-Path -LiteralPath $WorkflowPath) -Raw
function Assert-Contains([string]$Needle, [string]$Message) { if (-not $content.Contains($Needle)) { throw $Message } }
function Assert-NotContains([string]$Needle, [string]$Message) { if ($content.Contains($Needle)) { throw $Message } }

Assert-Contains 'workflow_dispatch:' 'Vertex release workflow must be manually dispatched.'
Assert-NotContains "`n  push:" 'Vertex release workflow must not run on push.'
Assert-NotContains "`n  pull_request:" 'Vertex release workflow must not run on pull requests.'
Assert-NotContains 'schedule:' 'Vertex release workflow must not run on a schedule.'
Assert-NotContains 'Pallav0099/' 'Vertex release workflow must use canonical xrigpc repositories.'
Assert-Contains 'xrigpc/xrig-platform' 'Vertex release workflow must check out XRIG Platform.'
Assert-Contains 'xrigpc/xrig-llama-backend' 'Vertex release workflow must check out tagged Vertex source.'
Assert-NotContains 'src/kai' 'Vertex-only publication must not check out or build Kai.'
Assert-Contains 'New-VertexReleaseManifest.ps1' 'Vertex release workflow must generate the Vertex manifest.'
Assert-Contains 'go test ./...' 'Vertex release workflow must run the Vertex Go suite.'
Assert-Contains '$PSNativeCommandUseErrorActionPreference = $true' 'Native test and build failures must fail the PowerShell release steps.'
Assert-Contains 'set -euo pipefail' 'Bash release steps must fail on any error.'
Assert-NotContains 'windows-latest' 'Vertex ships for Linux only; no Windows runner may be used.'
Assert-NotContains 'build-windows-gui' 'Vertex ships for Linux only; Windows must not be built.'
Assert-NotContains '.exe' 'Vertex ships for Linux only; no Windows executable may be built or published.'
Assert-NotContains 'Install-Vertex' 'Vertex ships for Linux only; no Windows installer may be published.'
Assert-Contains 'bash scripts/build-linux-gui.sh' 'Vertex release workflow must build the Linux GUI with the pinned Vertex build script.'
Assert-Contains 'bash scripts/build-linux-deb.sh' 'Vertex release workflow must build the Ubuntu package with the Vertex build script.'
Assert-Contains 'runs-on: ubuntu-24.04' 'The Ubuntu package must be built on the Ubuntu 24.04 ABI baseline.'
Assert-Contains 'go-version-file: src/vertex/.go-version' 'Go must come from the Vertex release toolchain pin.'
Assert-Contains 'node-version-file: src/vertex/.node-version' 'Node.js must come from the Vertex release toolchain pin.'
Assert-Contains 'verify-release' 'Vertex release workflow must verify the generated manifest with Platform.'
Assert-Contains '--mode verify-artifact --file "artifacts/$name"' 'Every signed asset must be verified with Platform before publication.'
Assert-Contains 'Prove release-key coherence with XRIG Platform' 'Release-key coherence proof is required.'
Assert-Contains "release_tag and vertex_tag must identify the same Vertex version." 'Vertex source tag must bind to the release tag.'
Assert-Contains "prerelease must be true only for a -rc.N release_tag." 'Vertex channel must bind to the release tag.'
Assert-Contains 'xrigpc/xrig-releases' 'Vertex release publication must target the canonical release repository.'
Assert-Contains ' --draft ' 'Assets must be uploaded to a draft before the release becomes public.'
Assert-Contains '--draft=false' 'The verified draft must be published explicitly.'
foreach ($asset in @('install-vertex-linux.sh', 'xrig-vertex_${VERTEX_VERSION}_amd64.deb', 'Expected 5 published Vertex assets')) {
    Assert-Contains $asset "Vertex release inventory must require $asset."
}
foreach ($legacy in @('llama-b9878', 'cudart-llama', 'gemma4-12b-5060ti', 'Install-Vertex-inner', 'Vertex-runtime-')) {
    Assert-NotContains $legacy "Vertex release workflow must not publish the legacy payload $legacy."
}
$jobsBlock = $content.Substring($content.IndexOf("`njobs:"))
$jobs = @([regex]::Matches($jobsBlock, '(?m)^  ([a-z-]+):\r?$') | ForEach-Object { $_.Groups[1].Value })
if (($jobs -join ',') -ne 'validate,release') { throw "Unexpected Vertex release jobs: $($jobs -join ', ')" }
if ([regex]::Matches($content, '(?m)^    environment: production\r?$').Count -ne 1) { throw 'Only the release job may use the production environment.' }
if ([regex]::Matches($content, '(?m)^\s+runs-on:\s+ubuntu-24\.04\r?$').Count -ne 2) { throw 'Every Vertex release job must run on Ubuntu 24.04.' }
# The signing key reaches only the steps that sign, never the whole job.
$releaseJob = $content.Substring($content.IndexOf("`n  release:"))
$jobEnv = [regex]::Match($releaseJob, '(?ms)^    env:\r?\n(.*?)^    steps:').Groups[1].Value
if ($jobEnv.Contains('secrets.')) { throw 'Release secrets must be scoped to the steps that use them.' }
$uses = @([regex]::Matches($content, '(?m)^\s+uses:\s+([^\r\n#]+)') | ForEach-Object { $_.Groups[1].Value.Trim() })
foreach ($action in $uses) { if ($action -notmatch '@[0-9a-f]{40}$') { throw "Action is not SHA pinned: $action" } }
Write-Host 'Vertex release workflow contract passed.'
