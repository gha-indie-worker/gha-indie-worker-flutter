# gha-indie-worker-flutter

Flutter client for IndieBuild across desktop, mobile, and web.

## Desktop control plane

On macOS, Linux, and Windows desktop builds, the app is a peer client of \`giw-desktop-daemon\`, alongside
\`giw-desktop-cli\` and \`gha-indie-worker-desktop-app.rs\`.

The app does not shell out to the CLI and does not supervise local services directly. All lifecycle mutations go
through the daemon:

- refresh local daemon status;
- reconcile \`giw-desktop-infra\` desired state;
- start/stop/restart declared local services;
- start/stop the named Cloudflare Tunnel;
- toggle **Keep IndieBuild alive during lock-screen / sleep**.

The real client is selected only for \`dart:io\` targets. Web uses a compile-safe unsupported stub. Android/iOS also
report desktop lifecycle control as unsupported, so adding this feature does not turn mobile clients into local
process supervisors.

## Authentication and endpoint rules

The desktop client reads the daemon bearer token from \`~/.giw/desktop/token\` by default and accepts
\`GIW_DESKTOP_TOKEN_FILE\` as a local override. It accepts only credential-free numeric loopback HTTP daemon URLs
with an explicit port via \`GIW_DESKTOP_URL\` (default \`http://127.0.0.1:18440\`). Hostnames such as \`localhost\`,
embedded credentials, non-root paths, queries, and fragments are rejected.

Daemon responses are capped at 1 MiB, request/connect activity is bounded by a five-second timeout, service names
are restricted to a path-safe manifest identifier, and protocol negotiation fails closed unless the daemon reports
protocol version 1.

Cloudflare API tokens, tunnel credentials, worker secrets, environment values, shell fragments, and executable
paths never cross the Flutter-to-daemon API boundary.

## Relationship to hosted IndieBuild

The hosted product/API remains \`https://indiebuild.dev\`. Desktop daemon control is a separate trust boundary and
must remain separate from normal cloud API calls. A desktop machine can be enrolled as self-hosted capacity while
still using the hosted IndieBuild control plane for jobs, leases, and product state.

## Source layout

- \`lib/src/desktop/daemon_models.dart\` — shared protocol-v1 models.
- \`lib/src/desktop/daemon_client.dart\` — conditional export.
- \`lib/src/desktop/daemon_client_io.dart\` — desktop/local HTTP implementation.
- \`lib/src/desktop/daemon_client_stub.dart\` — web/non-desktop-safe stub.
- \`lib/src/home_page.dart\` — desktop controls layered alongside the hosted-client surface.

No React is used.
