
# Private Network Service Platform

**Computer Networks Course Project · Phase 1 — Build & Observe · Phase 2 — Harden & Recover**

A two-Mac, fully local networking environment that demonstrates private DNS, HTTPS termination, reverse proxying, round-robin load balancing, HTTP cache validation, DNS resilience, backend isolation, failover, and packet-level troubleshooting.

> **Core idea:** The application is intentionally small. The main focus of this project is the network path and the behavior of its protocols and services.

## Contents

- [Project overview](#project-overview)
- [Architecture](#architecture)
- [Machines and services](#machines-and-services)
- [Request flow](#request-flow)
- [Technology stack](#technology-stack)
- [Repository layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Configuration and setup](#configuration-and-setup)
- [API endpoints](#api-endpoints)
- [Phase 1 verification](#phase-1-verification)
- [Phase 2 extensions and results](#phase-2-extensions-and-results)
- [Wireshark evidence](#wireshark-evidence)
- [Troubleshooting](#troubleshooting)
- [Security and cleanup](#security-and-cleanup)
- [Team](#team)

---

## Project overview

The platform uses two macOS laptops to host four logical network roles. Mac 1 runs the primary DNS resolver and Backend A. Mac 2 runs the backup DNS resolver, the active nginx HTTPS edge, and Backend B. A second nginx listener on Mac 1 is used as the target for the controlled DNS edge-migration test.

The private DNS namespace is `team1.test`:

- `app.team1.test` — application entry point
- `api.team1.test` — API entry point

The normal HTTPS entry point is `https://app.team1.test:8443` (or `https://api.team1.test:8443`). The edge terminates TLS and forwards requests to one of the two HTTP backends.

The environment is local to the team's private LAN. It does not require cloud hosting or external managed DNS/load-balancing services.

## Architecture

```text
                         Private Wi-Fi / LAN
                    10.7.0.0/19 · gateway 10.7.0.1

       Mac 1 — Shivansh Tiwari              Mac 2 — Navprabhat Singh
          10.7.19.246                           10.7.18.254
          Wi-Fi: en0                            Wi-Fi: en0

   +--------------------------+          +--------------------------+
   | Primary DNS              |          | Backup DNS               |
   | dnsmasq :53              |          | dnsmasq :53              |
   +------------+-------------+          +-------------+------------+
                |                                      |
                +----------- DNS lookup --------------+
                               |
                               v
                    app.team1.test / api.team1.test
                               |
                               v
                      HTTPS edge on Mac 2
                       nginx :8443 (TLS)
                               |
                    reverse proxy / round robin
                         /             \
                        /               \
                       v                 v
             Backend A                 Backend B
          Mac 1 :3001/HTTP        Mac 2 127.0.0.1:3002/HTTP
```

The DNS lookup and the HTTPS request are separate operations: DNS returns the address for the selected edge; the client then establishes TCP and TLS to that address. Nginx selects the backend, so the client does not need to know either backend address.

## Machines and services

| Machine | Team member | Observed IPv4 | Interface | Logical roles |
|---|---|---:|---|---|
| Mac 1 | Shivansh Tiwari | `10.7.19.246` | `en0` | Primary DNS, Backend A, standby/cutover nginx listener, test client |
| Mac 2 | Navprabhat Singh | `10.7.18.254` | `en0` | Backup DNS, active nginx edge/load balancer, Backend B, test client |

Both machines were observed with subnet mask `255.255.224.0` (`/19`) and default gateway `10.7.0.1`. The addresses are DHCP-assigned and may change. Re-check them before running the configuration or test commands:

```bash
networksetup -getinfo "Wi-Fi"
ipconfig getifaddr en0
```

### Service and port map

| Port | Protocol | Host | Service | Purpose |
|---:|---|---|---|---|
| 53 | UDP/TCP | Mac 1 | Primary `dnsmasq` | Primary private DNS resolver |
| 53 | UDP/TCP | Mac 2 | Backup `dnsmasq` | Backup private DNS resolver |
| 8443 | TCP/TLS | Mac 2 | Active nginx | HTTPS edge, TLS termination, reverse proxy, load balancing |
| 8443 | TCP/TLS | Mac 1 | Existing standby/cutover nginx listener | Controlled DNS-based edge migration target |
| 3001 | TCP/HTTP | Mac 1 | Backend A | Remote upstream reached by nginx over the LAN |
| 3002 | TCP/HTTP | Mac 2 | Backend B | Local upstream reached by nginx over loopback (`127.0.0.1`) |
| 5300 | UDP/TCP | Local test host | Temporary caching resolver | Isolated DNS TTL/cache experiment |

**Address note:** The values above are the addresses observed during the project tests, not static assignments. If DHCP changes either address, update both DNS configurations, the nginx upstream configuration, client resolver settings, and any PF rules that refer to the peer address.

## Request flow

1. The client queries a configured DNS resolver for `app.team1.test` or `api.team1.test`.
2. The resolver returns the A record for the selected HTTPS edge.
3. The client opens TCP to the edge on port `8443` (SYN, SYN-ACK, ACK).
4. TLS negotiation occurs; the client sends the HTTP request inside the encrypted TLS connection.
5. Nginx selects Backend A (`10.7.19.246:3001`) or Backend B (`127.0.0.1:3002`).
6. The backend returns JSON and an `X-Backend` response header. Nginx sends the response to the client over HTTPS.

## Technology stack

| Component | Role |
|---|---|
| macOS / Wi-Fi (`en0`) | Two-host private LAN environment |
| Homebrew | Package installation |
| Node.js | Backend HTTP/REST service runtime used in the recorded Phase 2 tests |
| Python | Phase 1 backend implementation retained in the project |
| `dnsmasq` | Primary DNS, backup DNS, local records and TTL behavior |
| nginx | TLS termination, reverse proxy and round-robin upstream selection |
| `mkcert` | Local development certificate and local CA |
| macOS PF (`pfctl`) | Backend-port access restrictions |
| `curl`, `dig`, `ping`, `nc`, `lsof`, `openssl` | Service checks and troubleshooting |
| Wireshark | DNS, TCP, TLS, HTTP and reset-packet inspection |

## Repository layout

The project is organised by service, configuration, scripts, documentation and evidence. The following is the intended layout described by the project files; if a local checkout has been reorganised, use the actual paths shown by `ls` before running a command.

```text
.
├── README.md
├── backend-a/
│   └── server.py
├── backend-b/
│   └── server.py
├── node-backend/
│   └── server.js
├── dns/
│   ├── dnsmasq.conf.example
│   ├── dnsmasq-primary.conf.example
│   ├── dnsmasq-backup.conf.example
│   └── dnsmasq-client-cache.conf.example
├── nginx/
│   ├── phase1.conf
│   ├── phase1.conf.example
│   ├── phase2-active.conf.example
│   └── phase2-standby.conf.example
├── firewall/
│   ├── pf-mac1.conf.example
│   └── pf-mac2.conf.example
├── scripts/
│   ├── run-backend-a.sh
│   ├── run-backend-b.sh
│   ├── run-backend-a-node.sh
│   ├── run-backend-b-node.sh
│   ├── test-backends.sh
│   ├── test-dns.sh
│   ├── test-dns-failover.sh
│   ├── test-https.sh
│   ├── test-load-balancing.sh
│   ├── test-phase2-services.sh
│   ├── demo-dns-ttl.sh
│   ├── test-firewall.sh
│   └── restore-dns.sh
├── docs/
│   ├── architecture.md
│   ├── phase1-checklist.md
│   ├── phase2-checklist.md
│   ├── phase2-implementation.md
│   ├── phase2-results.md
│   ├── phase2-demo-runbook.md
│   ├── troubleshooting.md
│   └── roles-and-responsibilities.md
├── tls/
│   └── README.md
├── evidence/
│   ├── README.md
│   ├── dns/
│   ├── phase2/
│   ├── caching/
│   ├── failures/
│   ├── https/
│   ├── load-balancing/
│   └── wireshark/
└── .gitignore
```

## Prerequisites

On both Macs:

- macOS with administrator access for service installation and PF configuration;
- Homebrew;
- Node.js and npm for the Node.js backend;
- `dnsmasq`, nginx and `mkcert`;
- both Macs connected to the same private Wi-Fi/LAN;
- permission to capture packets on the Wi-Fi interface using Wireshark.

Install the tools with Homebrew:

```bash
brew install node dnsmasq nginx mkcert
```

Check the installed commands:

```bash
node --version
npm --version
brew --prefix
dnsmasq --version
nginx -v 2>&1
mkcert -version
```

## Configuration and setup

> **Important:** The commands below show the two-machine deployment model. Review each `.example` configuration before installing it. In particular, confirm the current IP addresses, DNS A records, nginx certificate paths and PF peer address. Do not overwrite the host's existing network or PF configuration without keeping a rollback copy.

### 1. Verify LAN connectivity

Run on Mac 1:

```bash
ping -c 4 10.7.18.254
```

Run on Mac 2:

```bash
ping -c 4 10.7.19.246
```

The recorded tests returned four replies with no packet loss in each direction.

### 2. Configure primary and backup DNS

The primary `dnsmasq` configuration belongs on Mac 1 and the backup configuration belongs on Mac 2. Each configuration should listen on loopback and that machine's current LAN address, and should contain the same project A records.

Normal steady-state mapping:

```text
app.team1.test  -> 10.7.18.254
api.team1.test  -> 10.7.18.254
```

The application A record was intentionally changed to `10.7.19.246` during controlled edge-migration tests. Restore the normal mapping on **both** DNS servers after the migration test.

Directly query each resolver to identify which server answered:

```bash
dig @10.7.19.246 app.team1.test +noall +answer
dig @10.7.18.254 app.team1.test +noall +answer
```

The client resolver list used Mac 1 first and Mac 2 second. macOS resolver selection and retry behavior is operating-system dependent; the order should not be described as a guaranteed strict primary/secondary failover mechanism. The failover test stopped the primary service, flushed the client DNS cache, and confirmed an answer from `10.7.18.254`.

### 3. Start the backend services

The Node.js server is parameterised by backend identity and port. From the repository root, run the corresponding command on each host if the `node-backend/server.js` file is present:

**Mac 1 — Backend A:**

```bash
BACKEND_ID=A PORT=3001 node node-backend/server.js
```

**Mac 2 — Backend B:**

```bash
BACKEND_ID=B PORT=3002 node node-backend/server.js
```

Keep each service running while testing. In separate Terminal windows, verify health:

```bash
# On Mac 1
curl -i http://127.0.0.1:3001/health

# On Mac 2
curl -i http://127.0.0.1:3002/health
```

Expected JSON identifies the backend as `A` or `B` and reports a healthy status.

### 4. Configure TLS and nginx

Generate or install the local development certificate using the project's `mkcert` instructions. The certificate must cover both `app.team1.test` and `api.team1.test`. Nginx on Mac 2 is the active edge on TCP `8443`; its upstream pool contains Backend A at `10.7.19.246:3001` and Backend B at `127.0.0.1:3002`.

Validate nginx before starting or reloading it:

```bash
nginx -t
```

Then test the HTTPS endpoint. For a certificate-trust test, do **not** use `-k`:

```bash
curl -v https://app.team1.test:8443/api/status
```

If the local CA has not been trusted on the client, fix the trust-store setup rather than treating `curl -k` as successful certificate validation. A separate TLS transport test using `-k` does not prove that the certificate chain is trusted.

### 5. Configure backend isolation

The PF examples are stored under `firewall/`. The intended policy is:

- Mac 1: permit Backend A traffic from Mac 2 (the nginx edge), then block other inbound Wi-Fi traffic to port `3001`;
- Mac 2: block direct inbound Wi-Fi traffic to port `3002`; nginx reaches Backend B through loopback.

Review the host's parent PF configuration and anchor include before loading any rules. Keep a backup of the existing PF configuration and confirm the active rules with `pfctl` after loading. A rule file that has not been linked through the parent ruleset is not proof that the rule is active.

## API endpoints

| Method | Path | Cache behavior | Purpose |
|---|---|---|---|
| `GET` | `/` | Application response | Basic service identification |
| `GET` | `/api/status` | `Cache-Control: no-store` | Backend identifier, status, hostname and port |
| `GET` | `/health` | `Cache-Control: no-store` | Health check |
| `GET` | `/api/info` | `public, max-age=30` with ETag | HTTP cache-validation demonstration |

Backend responses expose the upstream selected by nginx:

```http
X-Backend: A
```

or

```http
X-Backend: B
```

The `/api/info` endpoint uses the ETag `"cn-project-v1"`. A matching `If-None-Match` request is expected to return `304 Not Modified` without a response body.

Example requests:

```bash
curl -i https://app.team1.test:8443/api/status
curl -i https://app.team1.test:8443/api/info
curl -i -H 'If-None-Match: "cn-project-v1"' \
  https://app.team1.test:8443/api/info
```

## Phase 1 verification

The following tests were recorded during the project:

| Test | Recorded result |
|---|---|
| LAN reachability | Bidirectional ping: 4/4 replies and 0% packet loss in the recorded runs |
| DNS | Primary and backup resolvers returned project records in direct-query tests |
| Backend services | Backend A on port `3001` and Backend B on port `3002` returned identifying JSON |
| HTTPS/TLS | TLS 1.2 negotiation and HTTPS response observed through nginx on port `8443` |
| Load balancing | Repeated HTTPS requests alternated `X-Backend: A` and `X-Backend: B` in baseline tests |
| HTTP cache validation | `200 OK` with `Cache-Control` and ETag, followed by `304 Not Modified` for a matching validator |
| Packet analysis | Wireshark screenshots show DNS, TCP/8443, TLS handshake and Backend A HTTP traffic |

Useful commands:

```bash
# Direct DNS queries
dig @10.7.19.246 app.team1.test +noall +answer
dig @10.7.18.254 app.team1.test +noall +answer

# Backend health
curl http://10.7.19.246:3001/health
curl http://127.0.0.1:3002/health

# Repeated load-balancer requests
for i in {1..10}; do
  curl -sS -D - -o /dev/null \
    https://app.team1.test:8443/api/status | grep -i '^X-Backend:'
done
```

## Phase 2 extensions and results

| Extension | Result recorded | Notes |
|---|---|---|
| A — Backup DNS resolver | **Verified** | With the primary resolver stopped and the client cache flushed, the client received answers from Mac 2 (`10.7.18.254`). |
| B — DNS TTL and controlled record change | **Verified** | An isolated cache test with a 30-second TTL showed the previous A record until expiry; a manual cache flush caused an immediate lookup of the changed record. |
| C — Backend isolation with PF | **Verified within the two-Mac test scope** | PF rules were loaded on both hosts; edge-to-backend traffic remained functional and a peer's direct request to Mac 2 port `3002` timed out. A third independent client was not available to probe every source against both backend ports. |
| D — Backend high-availability failover | **Verified** | Six requests were served by Backend B while Backend A was stopped. After A restarted, both A and B reappeared in the upstream response sequence. |
| E — DNS-based edge migration | **Cutover verified; overlap evidence not captured** | Changing the `app.team1.test` A record to Mac 1 reached an already-running nginx listener on `10.7.19.246:8443` and returned HTTP 200 from Backend A. The old-cache/new-edge overlap was not separately captured. |
| F — Faculty-injected troubleshooting | **Reserved for live evaluation** | The team practised layered diagnosis using observed DNS, TCP refusal, port conflict, stale PID and certificate-trust incidents. The faculty-selected fault itself is not claimed as completed. |

### Backend failover behavior

Nginx uses passive upstream failure handling (`max_fails`, `fail_timeout` and `proxy_next_upstream`). This is not continuous active health checking. In the recorded test, Backend A was stopped, six requests were served by Backend B, and after A was restarted the A/B distribution resumed.

### Known availability limitation

Mac 2's active nginx edge is still a single point of failure in the normal topology. Backup DNS and backend failover do not by themselves create another active HTTPS entry point. The Mac 1 nginx listener was used as a DNS cutover target, but the old-cache/new-edge overlap behavior should be demonstrated separately before claiming a fully seamless edge failover.

## Wireshark evidence

The project uses Wireshark on the Wi-Fi interface `en0`. Useful display filters:

| Purpose | Display filter |
|---|---|
| All DNS | `dns` |
| Project hostname query | `dns.qry.name == "app.team1.test"` |
| HTTPS edge TCP | `tcp.port == 8443` |
| TLS handshake | `tls.handshake` |
| Backend ports | `tcp.port == 3001 || tcp.port == 3002` |
| TCP resets | `tcp.flags.reset == 1` |

The collected screenshots document:

1. general DNS traffic, including project and unrelated laptop DNS activity;
2. the filtered `app.team1.test` query and its A-record answer at the captured instant;
3. the TCP three-way handshake to port `8443`;
4. TLS handshake messages, including SNI and certificate exchange;
5. HTTP traffic from Mac 2 to Backend A on Mac 1, including `GET /api/status` and an HTTP 200 JSON response;
6. TCP reset events observed during testing.

**Capture note:** Backend B is reached by nginx over Mac 2's loopback interface. A capture on `en0` may not show that loopback leg. Keep the original `.pcap` or `.pcapng` file when available; screenshots are useful report evidence but do not replace the packet capture.

## Troubleshooting

| Symptom | Likely layer / check |
|---|---|
| `dig` returns the wrong IP | DNS record drift or cached answer. Query each server explicitly with `dig @<server> ...`; inspect both dnsmasq files and the TTL. |
| `ping` works but `nc` reports connection refused | IP reachability is present, but the target TCP port has no accepting listener or is actively rejecting the connection. Check `lsof -nP -iTCP:<port> -sTCP:LISTEN`. |
| nginx reports `Address already in use` | Another process already owns the listener. Inspect with `lsof -nP -iTCP:8443 -sTCP:LISTEN`; reload the existing nginx instance rather than blindly starting another. |
| A saved PID cannot be killed | The PID file may be stale. Identify the live listener with `lsof` and verify the process before stopping it. |
| HTTPS handshake works but certificate verification fails | Check the certificate SANs, validity dates, client trust store and mkcert root CA installation. Do not confuse a successful TLS handshake with successful certificate-chain validation. |
| Backend B works locally but cannot be reached from the peer | Check the intended PF restriction and test via the nginx edge. Backend B is intended to be reached through `127.0.0.1:3002`. |

Use a layered diagnostic order: **DNS → IP/TCP → TLS → HTTP/application**. This helps identify which layer is failing before changing configuration.

## Security and cleanup

- Do not commit TLS private keys, the mkcert CA private key, passwords, or machine-specific secret files.
- Keep certificate and key files outside version control; add local runtime and capture artifacts to `.gitignore` as appropriate.
- Use `curl` without `-k` when demonstrating certificate trust. If `-k` is used for a temporary transport-only diagnostic, state clearly that it bypasses certificate validation.
- Back up PF configuration before changing it. Verify that the project anchor is actually included by the parent PF ruleset before relying on its rules.
- Record the current DNS settings before changing the macOS resolver list. Restore the original settings after the demonstration so normal network access is not disrupted.
- After migration tests, restore both DNS servers to the intended steady-state record (`app.team1.test` and `api.team1.test` pointing to the selected active edge).
- Stop only project-owned processes. Confirm process identity and listening ports before sending signals.

## Team

| Team member | Machine | Main responsibilities |
|---|---|---|
| Shivansh Tiwari | Mac 1 (`10.7.19.246`) | Primary DNS, Backend A, standby/cutover nginx listener, Mac 1 PF policy and testing |
| Navprabhat Singh | Mac 2 (`10.7.18.254`) | Backup DNS, active nginx HTTPS edge/load balancer, Backend B, Mac 2 PF policy, packet capture and testing |

---

## Project reference

- **Repository:** [ShivanshTIwaRISS/CN_Project](https://github.com/ShivanshTIwaRISS/CN_Project)
- **Project domain:** `team1.test`
- **Normal service URL:** `https://app.team1.test:8443`
- **Environment:** Two macOS laptops on a private LAN; no cloud hosting required.
