[CmdletBinding()]
param([string]$WorkflowPath = '')

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($WorkflowPath)) {
    $WorkflowPath = Join-Path $PSScriptRoot '..\.github\workflows\publish-release.yml'
}
$content = Get-Content -LiteralPath (Resolve-Path -LiteralPath $WorkflowPath) -Raw

function Assert-Contains([string]$Needle, [string]$Message) {
    if (-not $content.Contains($Needle)) { throw $Message }
}
function Assert-NotContains([string]$Needle, [string]$Message) {
    if ($content.Contains($Needle)) { throw $Message }
}

Assert-Contains 'workflow_dispatch:' 'Release workflow must be manually dispatched.'
Assert-NotContains "`n  push:" 'Release workflow must not run on push.'
Assert-NotContains "`n  pull_request:" 'Release workflow must not run on pull requests.'
Assert-NotContains 'schedule:' 'Release workflow must not run on a schedule.'
Assert-NotContains 'Pallav0099/' 'Release workflow must use canonical xrigpc repositories.'
Assert-NotContains 'src/vertex' 'Kai-only publication must not check out or build Vertex.'
Assert-NotContains 'Prepare-Kai-WindowsRuntime.ps1' 'Removed Kai runtime preparation hook must not be invoked.'
Assert-NotContains 'check-kai-brand.ps1' 'Removed brand hook must not be invoked.'
Assert-NotContains 'check-kai-release-policy.ps1' 'Removed policy hook must not be invoked.'
Assert-Contains 'New-KaiInstallBootstrap.ps1' 'Release workflow must generate a versioned Kai bootstrap.'
Assert-Contains 'check-kai-product-policy.ps1' 'Release workflow must run the Kai package policy gate.'
Assert-Contains 'python-version: 3.12.10' 'Release workflow must build against the locked CPython runtime.'
Assert-Contains 'npm run dist:win:nsis --workspace apps/desktop -- --publish never' 'Electron build must never publish directly.'
Assert-Contains 'xrigpc/xrig-releases' 'Release publication must target the canonical release repository.'
Assert-Contains 'verify-release' 'Release workflow must verify the generated manifest with Platform.'
Assert-Contains 'Prove release-key coherence with XRIG Platform' 'Release-key coherence proof is required.'
Assert-Contains "release_tag and kai_tag must identify the same Kai version." 'Release workflow must bind the source tag to the release tag.'
Assert-Contains "prerelease must be true only for a -rc.N release_tag." 'Release workflow must bind the channel to the release tag.'
Assert-Contains 'npm ci --workspace apps/desktop --workspace apps/shared' 'Release workflow must install only the packaged Kai workspaces.'
Assert-NotContains 'npm run build --workspace web' 'Release workflow must not build the unshipped web workspace.'
Assert-NotContains 'npm run build --workspace ui-tui' 'Release workflow must not build the unshipped Node TUI workspace.'
Assert-Contains 'Kai document-search imports passed.' 'Release workflow must assert document-search imports.'
Assert-Contains 'check-kai-package-policy.cjs' 'Release workflow must scan the unpacked package payload.'

$uses = @([regex]::Matches($content, '(?m)^\s+uses:\s+([^\r\n#]+)') | ForEach-Object { $_.Groups[1].Value.Trim() })
foreach ($action in $uses) {
    if ($action -notmatch '@[0-9a-f]{40}$') { throw "Action is not SHA pinned: $action" }
}

Write-Host 'Kai release workflow contract passed.'
