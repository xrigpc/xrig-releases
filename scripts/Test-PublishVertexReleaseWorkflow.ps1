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
Assert-Contains 'wails build -tags xrigapp -platform windows/amd64' 'Vertex release workflow must build the Wails application.'
Assert-Contains 'verify-release' 'Vertex release workflow must verify the generated manifest with Platform.'
Assert-Contains 'Prove release-key coherence with XRIG Platform' 'Release-key coherence proof is required.'
Assert-Contains "release_tag and vertex_tag must identify the same Vertex version." 'Vertex source tag must bind to the release tag.'
Assert-Contains "prerelease must be true only for a -rc.N release_tag." 'Vertex channel must bind to the release tag.'
Assert-Contains 'xrigpc/xrig-releases' 'Vertex release publication must target the canonical release repository.'
$uses = @([regex]::Matches($content, '(?m)^\s+uses:\s+([^\r\n#]+)') | ForEach-Object { $_.Groups[1].Value.Trim() })
foreach ($action in $uses) { if ($action -notmatch '@[0-9a-f]{40}$') { throw "Action is not SHA pinned: $action" } }
Write-Host 'Vertex release workflow contract passed.'
