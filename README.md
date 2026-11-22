# Private Network Service Platform — Phase 1 & Phase 2

**Course:** Computer Networks Course Project  
**Target Environment:** macOS (Up to 4 laptops; deployed across 2 physical MacBooks with combined logical roles)  
**Private Domain Namespace:** `team1.test` (`app.team1.test`, `api.team1.test`)  
**Deployment Type:** 100% Fully Local Private LAN — No Cloud Hosting Required

---

## 1. Project Purpose & Executive Summary

The **Private Network Service Platform** is an enterprise-grade private service environment constructed entirely from scratch across physical MacBooks on a shared local network. Rather than relying on managed cloud infrastructure (such as AWS Route 53, Application Load Balancers, or Cloudflare), every network layer is built, configured, and operated directly by the team:

- **Private DNS Resolution:** Authoritative and redundant local DNS servers (`dnsmasq`) with TTL management and failover.
- **TLS Termination & Edge Routing:** Reverse proxying, TLS 1.2/1.3 termination with trusted local certificates, and client traffic abstraction (`nginx`).
- **Application Services:** Dual HTTP REST backend instances featuring status monitoring, cache validation, and ETag revalidation.
- **Network Resilience:** High-availability passive upstream failover and warm standby edge migration.
- **Service Isolation:** Kernel-level packet filtering via macOS Packet Filter (`pfctl`) to isolate application backends.
- **Empirical Protocol Analysis:** Full packet-level verification of DNS queries, TCP three-way handshakes, TLS handshakes, and HTTP/1.1 exchanges.

> **Core Principle:** *The application stays simple — the network is the project.*

---

## 2. Team Members & Physical Machine Allocation

Following course constraints for a two-student team, the four logical networking roles are distributed across two physical Apple MacBooks:

| Machine | Student Name | LAN IPv4 Address (`en0`) | Logical Roles & Services |
|---------|--------------|--------------------------|--------------------------|
| **Mac 1** | **Shivansh Tiwari** | `10.7.19.246` | • **Primary DNS Resolver** (`dnsmasq` port 53)<br>• **Backend Server A** (Node.js/Python port 3001)<br>• **Standby HTTPS Reverse Proxy** (`nginx` port 8443)<br>• **Service Isolation Anchor** (`pfctl` port 3001)<br>• **DNS & Application Testing Client** |
| **Mac 2** | **Nav Prabhat Singh** | `10.7.18.254` | • **Backup DNS Resolver** (`dnsmasq` port 53)<br>• **Active HTTPS Edge & Load Balancer** (`nginx` port 8443)<br>• **Backend Server B** (Node.js/Python port 3002)<br>• **Service Isolation Anchor** (`pfctl` port 3002)<br>• **DNS & Application Testing Client** |

> [!NOTE]
> **DHCP Address Notice:** IP addresses (`10.7.19.246` and `10.7.18.254`) are assigned via DHCP on the local private Wi-Fi network. Configuration templates and scripts use parameterized environment variables (`MAC1_IP`, `MAC2_IP`, `PRIMARY_DNS`, `BACKUP_DNS`) making updates straightforward if DHCP leases change.

---

## 3. Network Architecture & Topology

```
                                  Shared Private LAN
                     (Wi-Fi / 10.7.0.0/16 Subnet - en0 Interfaces)
         ══════════════════════════════════════════════════════════════════
                         ║                                  ║
         ┌───────────────╨────────────────┐ ┌───────────────╨────────────────┐
         │             Mac 1              │ │             Mac 2              │
         │     Owner: Shivansh Tiwari     │ │    Owner: Nav Prabhat Singh    │
         │         (10.7.19.246)          │ │         (10.7.18.254)          │
         ├────────────────────────────────┤ ├────────────────────────────────┤
         │ [Primary DNS Resolver]         │ │ [Backup DNS Resolver]          │
         │  dnsmasq (Port 53)             │ │  dnsmasq (Port 53)             │
         │                                │ │                                │
         │ [Standby HTTPS Edge]           │ │ [Active HTTPS Edge & LB]       │
         │  nginx (Port 8443)             │ │  nginx (Port 8443)             │
         │                                │ │                                │
         │ [Backend Server A]             │ │ [Backend Server B]             │
         │  Node.js / Python (Port 3001)  │ │  Node.js / Python (Port 3002)  │
         │                                │ │                                │
         │ [Packet Filter Anchor]         │ │ [Packet Filter Anchor]         │
         │  pfctl com.apple/cnproject     │ │  pfctl com.apple/cnproject     │
         │                                │ │                                │
         │ [Test & Diagnosis Client]      │ │ [Test & Diagnosis Client]      │
         └────────────────────────────────┘ └────────────────────────────────┘
```

### Port Allocation Table

| Port | Protocol | Host Machine | Bound Service | Public / Internal Scope |
|------|----------|--------------|---------------|-------------------------|
| `53` | UDP/TCP | Mac 1 (`10.7.19.246`) | Primary `dnsmasq` Resolver | LAN accessible (`127.0.0.1, 10.7.19.246`) |
| `53` | UDP/TCP | Mac 2 (`10.7.18.254`) | Backup `dnsmasq` Resolver | LAN accessible (`127.0.0.1, 10.7.18.254`) |
| `8443` | TCP (TLS) | Mac 2 (`10.7.18.254`) | Active `nginx` HTTPS Edge | Public LAN entry point (`0.0.0.0:8443`) |
| `8443` | TCP (TLS) | Mac 1 (`10.7.19.246`) | Standby `nginx` HTTPS Edge | Warm standby for migration (`0.0.0.0:8443`) |
| `3001` | TCP (HTTP)| Mac 1 (`10.7.19.246`) | Backend A (REST API) | Internal service (protected by PF firewall) |
| `3002` | TCP (HTTP)| Mac 2 (`10.7.18.254`) | Backend B (REST API) | Internal service (loopback only / PF protected) |
| `5300` | UDP/TCP | Mac 1 (`127.0.0.1`) | Caching DNS Resolver | Localhost only (isolated TTL test suite) |

---

## 4. Operational DNS States

The platform implements two controlled DNS operational configurations:

### State 1: Normal Operational Baseline (Active Edge on Mac 2)
- `app.team1.test` → `10.7.18.254` (Mac 2 Active Nginx)
- `api.team1.test` → `10.7.18.254` (Mac 2 Active Nginx)
- Traffic arrives at Mac 2 port 8443, terminates TLS, and load balances 50/50 across Backend A (`10.7.19.246:3001`) and Backend B (`127.0.0.1:3002`).

### State 2: Controlled Edge Migration (Standby Edge on Mac 1)
- `app.team1.test` → `10.7.19.246` (Mac 1 Standby Nginx)
- `api.team1.test` → `10.7.18.254` (Mac 2 Active Nginx - unchanged)
- Demonstrates traffic cutover without service disruption or new hardware.

---

## 5. Backend Runtimes & Endpoints

To preserve the working Phase 1 Python implementation while maintaining complete fidelity to the live Phase 2 tested Node.js implementation, both runtimes are supported and reconciled:

- **Phase 1 Baseline (Python):** `backend-a/server.py` and `backend-b/server.py`
- **Phase 2 Tested Runtime (Node.js):** `node-backend/server.js` (parameterized via `BACKEND_ID=A|B` and `PORT=3001|3002`)

### API Specification & Endpoints

| Method | Endpoint | Cache-Control | Content-Type | Response Structure / Description |
|--------|----------|---------------|--------------|----------------------------------|
| `GET` | `/` | — | `application/json` | Welcome payload confirming service running & hostname |
| `GET` | `/api/status` | `no-store` | `application/json` | Status check: `{"backend":"A/B","status":"ok","port":3001/3002}` |
| `GET` | `/health` | `no-store` | `application/json` | Health probe: `{"backend":"A/B","status":"healthy"}` |
| `GET` | `/api/info` | `public, max-age=30` | `application/json` | Caching test: returns payload with `ETag: "cn-project-v1"`; supports conditional `304 Not Modified` |

### Required Response Header
Every backend response includes the mandatory routing header:
```http
X-Backend: A    (or X-Backend: B)
```

---

## 6. Phase 2 Extensions & Status Verification Table

| Extension | Title | Target Subsystem | Implementation Status | Verified Evidence Location |
|-----------|-------|------------------|-----------------------|----------------------------|
| **Extension A** | Backup DNS Resolver | DNS Redundancy | **PASSED** | Primary failure test; backup answered via `10.7.18.254` |
| **Extension B** | DNS TTL & Controlled Record Change | DNS Caching / TTL | **PASSED** | Full decrement & SIGHUP flush log: `evidence/dns/ttl-proof.txt` |
| **Extension C** | Service Isolation (Backend Firewall) | macOS Packet Filter | **PASSED WITH TWO-MAC TOPOLOGY LIMITATION** | Direct access timeout log: `evidence/phase2/phase2-mac1-test.txt` |
| **Extension D** | High Availability Backend Failover | Nginx Upstream HA | **PASSED** | Passive failover & recovery sequence: `B, B, A, B, A, B, A, B` |
| **Extension E** | Controlled Edge Migration | DNS Cutover | **IMPLEMENTED AND MIGRATION VERIFIED; OLD-CACHE/NEW-EDGE OVERLAP EVIDENCE PENDING** | Standby edge routing to Backend A verified; overlap evidence pending |
| **Extension F** | Faculty-Injected Troubleshooting | Multi-Layer Diagnostics | **PENDING LIVE FACULTY EVALUATION** | Diagnostic handbook: `docs/troubleshooting.md` |

---

## 7. Deep-Dive: Phase 2 Extension Architecture

### Extension A: Backup DNS Resolver
- **Primary:** `10.7.19.246:53` (Mac 1). **Backup:** `10.7.18.254:53` (Mac 2).
- Client stub resolvers configure both nameservers: `networksetup -setdnsservers "Wi-Fi" 10.7.19.246 10.7.18.254`.
- **Fault Test:** Primary `dnsmasq` stopped on Mac 1. Client `dig app.team1.test` resolved seamlessly to `10.7.18.254` with `SERVER: 10.7.18.254#53`.
- Primary restarted and both resolvers synchronized.

### Extension B: DNS TTL & Controlled Record Change
- Uses `local-ttl=30` in authoritative `dnsmasq`.
- Dedicated caching resolver run on Mac 1 at `127.0.0.1:5300` forwarding to `10.7.19.246:53`.
- **Observed sequence in `evidence/dns/ttl-proof.txt`:**
  1. Initial cache: `10.7.18.254` (TTL 30).
  2. Authoritative changed to `10.7.19.246`.
  3. Caching resolver continued returning stale `10.7.18.254` with decrementing TTL (observed TTL 25).
  4. At 30s expiry, cache refreshed and returned `10.7.19.246` (TTL 30).
  5. Authoritative changed back to `10.7.18.254`; cached answer returned `10.7.19.246` (TTL 26).
  6. Sending `kill -HUP` flushed cache immediately; next query returned `10.7.18.254` (TTL 30).

### Extension C: Service Isolation via macOS Packet Filter (PF)
- Anchors created under `com.apple/cnproject` to protect macOS baseline configuration.
- **Mac 1 Policy (`firewall/pf-mac1.conf.example`):** Allows incoming port 3001 exclusively from Mac 2 (`10.7.18.254`) and loopback; drops all other incoming connections to 3001.
- **Mac 2 Policy (`firewall/pf-mac2.conf.example`):** Restricts port 3002 to loopback (`127.0.0.1`); blocks all incoming LAN connections to 3002.
- **Observed Result:** Direct `curl http://10.7.18.254:3002/` from Mac 1 timed out after 3004 ms, while Nginx reverse proxy access remained completely healthy.
- **Topology Limitation Disclosure:** Two physical MacBooks cannot execute an independent 3rd client machine unauthorized probe against Mac 1 Backend A.

### Extension D: High Availability Failover
- Active Nginx upstream pool:
  ```nginx
  upstream backend_pool {
      server 10.7.19.246:3001 max_fails=1 fail_timeout=10s;
      server 127.0.0.1:3002 max_fails=1 fail_timeout=10s;
  }
  ```
- Passive failover directives: `proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;`.
- **Fault Test:** Backend A process killed. Six consecutive client requests returned `200 OK` with `X-Backend: B` without client error.
- **Recovery Test:** Backend A restarted. Requests demonstrated automatic recovery sequence: `B, B, A, B, A, B, A, B`.
- **SPOF Analysis:** Active Nginx on Mac 2 is an edge single point of failure; standby edge on Mac 1 mitigates this through DNS migration.

### Extension E: Controlled Edge Migration
- Standby Nginx on Mac 1 (`10.7.19.246:8443`) configured with identical TLS certificates.
- Authoritative DNS cutover: `app.team1.test` → `10.7.19.246`.
- Direct HTTPS request reached Mac 1 and served Backend A.

### Extension F: Faculty-Injected Troubleshooting
- Reserved for live faculty evaluation slot.
- Comprehensive diagnostic runbook available in `docs/troubleshooting.md`.

---

## 8. Installation & Setup Runbooks

### Prerequisites
Install Homebrew dependencies on both Macs:
```bash
brew install dnsmasq nginx mkcert
```

### Mac 1 Setup (Shivansh Tiwari — 10.7.19.246)
1. **Configure Primary DNS:**
   ```bash
   sudo cp dns/dnsmasq-primary.conf.example /opt/homebrew/etc/dnsmasq.conf
   sudo brew services start dnsmasq
   ```
2. **Start Backend A (Node.js):**
   ```bash
   ./scripts/run-backend-a-node.sh &
   ```
3. **Configure Standby Nginx (for Extension E):**
   ```bash
   sudo cp nginx/phase2-standby.conf.example /opt/homebrew/etc/nginx/servers/phase2-standby.conf
   ```

### Mac 2 Setup (Nav Prabhat Singh — 10.7.18.254)
1. **Configure Backup DNS:**
   ```bash
   sudo cp dns/dnsmasq-backup.conf.example /opt/homebrew/etc/dnsmasq.conf
   sudo brew services start dnsmasq
   ```
2. **Start Backend B (Node.js):**
   ```bash
   ./scripts/run-backend-b-node.sh &
   ```
3. **Start Active Nginx Edge & Load Balancer:**
   ```bash
   sudo cp nginx/phase2-active.conf.example /opt/homebrew/etc/nginx/servers/phase2-active.conf
   sudo nginx -t && sudo brew services start nginx
   ```

### Client DNS Configuration (Run on Both Macs)
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.19.246 10.7.18.254
```

---

## 9. Verification & Test Scripts

All scripts are stored in `scripts/` and have been verified with `bash -n`:

```bash
# Test Primary and Backup DNS
./scripts/test-dns.sh

# Test DNS failover
./scripts/test-dns-failover.sh

# Test direct backend responses (Ports 3001 & 3002)
./scripts/test-backends.sh

# Test HTTPS, TLS trust, and Caching / ETag (no -k)
./scripts/test-https.sh

# Test round-robin load balancing (10 requests)
./scripts/test-load-balancing.sh

# Audit all local Phase 2 service ports
./scripts/test-phase2-services.sh

# Run the automated DNS TTL experiment
./scripts/demo-dns-ttl.sh

# Verify Service Isolation & Packet Filter status
./scripts/test-firewall.sh

# Safely restore baseline normal DNS
./scripts/restore-dns.sh
```

---

## 10. Final 11-Step Demonstration Sequence

For the live evaluation, follow the sequence in [`docs/phase2-demo-runbook.md`](docs/phase2-demo-runbook.md):
1. **Step 1:** Present network topology diagram and machine inventory table (`docs/architecture.md`).
2. **Step 2:** Execute bidirectional ping between Mac 1 and Mac 2 (confirm 0.0% loss).
3. **Step 3:** Resolve `app.team1.test` via DNS (`dig app.team1.test`).
4. **Step 4:** Open `https://app.team1.test:8443` over HTTPS without certificate warnings (no `-k`).
5. **Step 5:** Demonstrate round-robin load balancing (`./scripts/test-load-balancing.sh`).
6. **Step 6:** Inspect Wireshark packet captures (DNS query/reply, TCP 3-way handshake, TLS handshake).
7. **Step 7:** Demonstrate HTTP caching (`Cache-Control: public, max-age=30`) and ETag revalidation (`304 Not Modified`).
8. **Step 8:** Stop Backend A; verify transparent failover to Backend B (`X-Backend: B`), restart Backend A, show recovery sequence.
9. **Step 9:** Demonstrate Phase 2 resilience (Backup DNS failover, TTL decrement, or Edge cutover).
10. **Step 10:** Diagnose faculty-injected configuration fault using [`docs/troubleshooting.md`](docs/troubleshooting.md).
11. **Step 11:** Individual viva defense based on component ownership.

---

## 11. Security & Hygiene Rules

| Security Principle | Enforcement Detail |
|--------------------|--------------------|
| **No Private Keys Committed** | `*.key`, `*.pem`, `*.csr`, and `*.srl` are strictly ignored by `.gitignore` |
| **No Insecure Curl Calls** | Never recommend or use `curl -k` / `--insecure`. Local Root CA is installed in macOS Keychain |
| **No Hardcoded Passwords** | All configurations and scripts use sanitized environment variables |
| **Safe Packet Filter Rollback** | Rules run exclusively inside anchor `com.apple/cnproject`; roll back via `sudo pfctl -a com.apple/cnproject -F all` |
| **No Disruption to Main Network** | `scripts/restore-dns.sh` provides safe restoration to normal operational baseline |

---

## 12. Complete Documentation Directory

| Document | Description |
|----------|-------------|
| [`docs/architecture.md`](docs/architecture.md) | Full 2-Mac network topology, service mapping, request flow diagrams, and protocol stack analysis |
| [`docs/phase1-checklist.md`](docs/phase1-checklist.md) | Completed Phase 1 build and observation verification checklist |
| [`docs/phase2-checklist.md`](docs/phase2-checklist.md) | Phase 2 hardening, resilience, and failover verification checklist |
| [`docs/phase2-implementation.md`](docs/phase2-implementation.md) | Technical implementation guide for all six Phase 2 extensions |
| [`docs/phase2-results.md`](docs/phase2-results.md) | Empirical test transcripts, data tables, and verification outputs |
| [`docs/phase2-demo-runbook.md`](docs/phase2-demo-runbook.md) | Step-by-step 11-step final demonstration script for evaluators |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Systematic 4-layer diagnostic guide and fault isolation matrix |
| [`docs/roles-and-responsibilities.md`](docs/roles-and-responsibilities.md) | Individual responsibilities, port allocation, and viva preparation guide |
| [`evidence/README.md`](evidence/README.md) | Directory guide and catalog of empirical proof files |
| [`tls/README.md`](tls/README.md) | Certificate Authority architecture, generation commands, and trust store setup |

---

## 13. Repository Tree

```
.
├── .gitignore                                 Git exclusions (keys, pem, pcap, logs)
├── README.md                                  Master project documentation
├── backend-a/
│   └── server.py                              Phase 1 Python Backend A (port 3001)
├── backend-b/
│   └── server.py                              Phase 1 Python Backend B (port 3002)
├── node-backend/
│   └── server.js                              Phase 2 Node.js Backend (ports 3001/3002, ETag, Caching)
├── dns/
│   ├── dnsmasq.conf.example                   Baseline dnsmasq configuration
│   ├── dnsmasq-primary.conf.example           Phase 2 Primary DNS (Mac 1)
│   ├── dnsmasq-backup.conf.example            Phase 2 Backup DNS (Mac 2)
│   └── dnsmasq-client-cache.conf.example      Isolated local caching resolver (port 5300)
├── nginx/
│   ├── phase1.conf                            Baseline Nginx reverse proxy
│   ├── phase1.conf.example                    Baseline template
│   ├── phase2-active.conf.example             Phase 2 Active Edge & HA LB (Mac 2)
│   └── phase2-standby.conf.example            Phase 2 Standby Edge (Mac 1)
├── firewall/
│   ├── pf-mac1.conf.example                   Mac 1 PF rule (protect Backend A)
│   └── pf-mac2.conf.example                   Mac 2 PF rule (protect Backend B)
├── scripts/
│   ├── run-backend-a.sh                       Launch Python Backend A
│   ├── run-backend-b.sh                       Launch Python Backend B
│   ├── run-backend-a-node.sh                  Launch Node.js Backend A
│   ├── run-backend-b-node.sh                  Launch Node.js Backend B
│   ├── test-backends.sh                       Test direct backend HTTP responses
│   ├── test-dns.sh                            Test Primary & Backup DNS queries
│   ├── test-dns-failover.sh                   Test DNS redundancy & failover
│   ├── test-https.sh                          Test HTTPS & ETag 304 revalidation
│   ├── test-load-balancing.sh                 Test round-robin distribution
│   ├── test-phase2-services.sh                Audit local listening ports & services
│   ├── demo-dns-ttl.sh                        Automated DNS TTL decrement test
│   ├── test-firewall.sh                       Test service isolation & PF status
│   └── restore-dns.sh                         Restore baseline normal DNS
├── docs/
│   ├── architecture.md                        Architecture & protocol stack documentation
│   ├── phase1-checklist.md                    Phase 1 completed checklist
│   ├── phase2-checklist.md                    Phase 2 completed checklist
│   ├── phase2-implementation.md               Phase 2 implementation guide
│   ├── phase2-results.md                      Empirical test results & logs
│   ├── phase2-demo-runbook.md                 11-step evaluation sequence
│   ├── troubleshooting.md                     4-layer diagnostic guide
│   └── roles-and-responsibilities.md          Team ownership & viva prep
├── tls/
│   └── README.md                              Local CA & trust instructions
└── evidence/
    ├── README.md                              Evidence catalog & guide
    ├── dns/
    │   └── ttl-proof.txt                      Captured Extension B TTL proof
    ├── phase2/
    │   └── phase2-mac1-test.txt               Captured Mac 1 integrated test audit
    ├── caching/                               Cache-Control & ETag 304 traces
    ├── failures/                              Failure & negative proof outputs
    ├── https/                                 TLS verification outputs
    ├── load-balancing/                        Round-robin test outputs
    └── wireshark/                             Wireshark packet capture guides
```
