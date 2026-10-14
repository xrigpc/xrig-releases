# XRIG Releases

This public repository is the distribution channel for XRIG AI PC application
releases. It intentionally contains **no Kai, Vertex, or XRIG Platform source
code** and no release binary is committed to Git history.

Every production binary, inner installer, bootstrap, manifest, and signature is
uploaded as a GitHub Release asset by a protected product-specific workflow.
The signed `xrig-release-v1.manifest` is the release
authority; GitHub's `latest` route is only a download selector.

## What is published

- `Install-Kai.ps1` and `install-vertex-linux.sh` public bootstraps;
- the signed `xrig-identity.exe` verifier, Kai's Windows binaries and its
  verified inner installer, locked llama.cpp/CUDA runtime archives, and the
  factory model configuration (model bytes download directly from the pinned
  public Hugging Face entries in that configuration);
- the Vertex application only, for Linux: its Ubuntu package
  `xrig-vertex_<version>_amd64.deb`. Vertex no longer ships for Windows (the
  Windows sources remain in Vertex but are not built or published). Vertex
  runtime stacks (llama.cpp, Strata) and model configurations are signed and
  versioned independently and are not part of a Vertex release;
- an Ed25519 signature for every release payload and the canonical manifest.

The release copy of `xrig-identity.exe` is a signed verifier/repair artifact;
it is not an activation bootstrap. Register, Activate, and Reactivate remain on
XRIG Platform's private factory/support path. Product installers only proceed
after the already installed Platform passes local Verify and its online
active-device check.

## Release workflow

Run the appropriate workflow manually from this repository. Each requires exact
**tags**, not branches, for the XRIG Platform verifier and its product source:

- `xrigpc/xrig-platform`
- `xrigpc/kai` for `publish-release.yml`
- `xrigpc/xrig-llama-backend` for `publish-vertex-release.yml`

The Kai workflow compiles Kai only. The Vertex workflow tests, builds, signs
and publishes the Ubuntu package from one protected Ubuntu 24.04 job (the
package's glibc baseline), so a Vertex release needs one `production` approval.
A Vertex release has five assets: `install-vertex-linux.sh`, the `.deb` and
its signature, and the manifest and its signature. Both workflows validate the signed
manifest, and the Vertex workflow also verifies every signed asset, with the
Platform verifier. Assets are uploaded to a draft that becomes a GitHub
pre-release or stable release only after its inventory matches. The
cross-product version field is compatibility metadata, not a rebuilt payload. A
versioned asset is never replaced with different bytes.

The manifest signs its channel: a `-rc.N` tag is always `candidate` and a plain
tag is always `stable`. A candidate is therefore never promoted by editing the
GitHub release; publish the stable version with its own tag and run.

## Required protected-environment configuration

Create a `production` environment for this repository and protect it with the
factory release approver. Configure only these values there:

- `XRIG_SOURCE_READ_TOKEN` — a fine-grained token limited to **Contents: Read**
  on the two private source repositories above.
- `XRIG_RELEASE_SIGNING_PKCS8_B64` — the existing XRIG Ed25519 signing key,
  Base64-encoded. It is used only while signing release assets on the protected
  runner.
- `XRIG_SUPABASE_ANON_KEY` — Platform public activation metadata.
- `XRIG_ACTIVATION_RESPONSE_PUBLIC_KEY_HEX` — Platform public activation
  response key.

The workflow's built-in `GITHUB_TOKEN` has write access only to this repository
and is used to create the GitHub Release. No Supabase storage token is used for
Kai or Vertex release publication.

## Factory pre-release command

GitHub's `latest` selector excludes pre-releases. For a factory candidate, save
the versioned bootstrap, then pass that same tag explicitly:

```powershell
$tag = 'v1.0.2-rc.1'
Invoke-WebRequest "https://github.com/xrigpc/xrig-releases/releases/download/$tag/Install-Kai.ps1" -OutFile .\Install-Kai.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Kai.ps1
```

For a Vertex candidate:

```bash
tag=v1.1.0-rc.2
curl -fsSL "https://github.com/xrigpc/xrig-releases/releases/download/$tag/install-vertex-linux.sh" |
  XRIG_VERTEX_RELEASE_ROOT="https://github.com/xrigpc/xrig-releases/releases/download/$tag" bash
```

This is only for factory and clean-runner pre-release validation; owner
installation always uses the stable URL below.

## Public stable URLs

Once a stable release is published, the public installation endpoints are:

```powershell
irm https://github.com/xrigpc/xrig-releases/releases/latest/download/Install-Kai.ps1 | iex
```

```bash
curl -fsSL https://github.com/xrigpc/xrig-releases/releases/latest/download/install-vertex-linux.sh | bash
```

The initial bootstrap is HTTPS-trusted by design. Before elevation or product
mutation, it must call XRIG Platform, validate the active device online, and
verify the signed manifest plus each immutable artifact.
