# Phase 2 Evidence Checklist — Harden, Recover, and Troubleshoot

This document tracks the implementation, testing status, and evidence for the six mandatory Phase 2 extensions of the Computer Networks project.

---

## Phase 2 Extension Summary Table

| Extension | Title | Target Subsystem | Status | Primary Evidence |
|-----------|-------|------------------|--------|------------------|
| **Extension A** | Backup DNS Resolver | DNS Redundancy | **PASSED** | Dual resolver query logs & failover test |
| **Extension B** | DNS TTL & Controlled Record Change | DNS Caching / TTL | **PASSED** | `evidence/dns/ttl-proof.txt` |
| **Extension C** | Service Isolation / Backend Firewall | Network Security (PF) | **PASSED WITH TWO-MAC TOPOLOGY LIMITATION** | `evidence/phase2/phase2-mac1-test.txt` & `firewall/` configs |
| **Extension D** | High Availability Backend Failover | Nginx Upstream HA | **PASSED** | Active failover sequence: `B, B, A, B, A, B, A, B` |
| **Extension E** | Controlled Edge Migration | DNS Cutover & Standby Edge | **IMPLEMENTED AND MIGRATION VERIFIED; OLD-CACHE/NEW-EDGE OVERLAP EVIDENCE PENDING** | Standby Nginx tests & DNS migration |
| **Extension F** | Faculty-Injected Troubleshooting | Multi-Layer Diagnostics | **PENDING LIVE FACULTY EVALUATION** | `docs/troubleshooting.md` |

---

## Detailed Extension Verification

### Extension A — Backup DNS Resolver
- [x] Primary `dnsmasq` instance running on Mac 1 (`10.7.19.246:53`).
- [x] Backup `dnsmasq` instance running on Mac 2 (`10.7.18.254:53`).
- [x] Identical project DNS records (`app.team1.test` and `api.team1.test`) configured on both resolvers.
- [x] Client Macs configured with both nameservers (`10.7.19.246` and `10.7.18.254`).
- [x] **Failure demonstration:** Primary DNS daemon stopped on Mac 1; client successfully resolves `app.team1.test` and `api.team1.test` via Backup DNS (`10.7.18.254`).
- [x] Primary DNS service restarted; both resolvers verified functional.
- **Verification Result:** **PASSED**

---

### Extension B — DNS TTL and Controlled Record Change
- [x] Authoritative TTL configured to `local-ttl=30` in `dnsmasq`.
- [x] Dedicated client caching resolver deployed on Mac 1 (`127.0.0.1:5300`) forwarding to authoritative DNS (`10.7.19.246:53`).
- [x] Initial query caches `10.7.18.254` with TTL 30.
- [x] Authoritative record changed to `10.7.19.246`.
- [x] Caching resolver proves stale cache return with decreasing TTL (observed TTL 25).
- [x] Following 30-second expiry, caching resolver refreshes and serves `10.7.19.246` with fresh TTL 30.
- [x] Authoritative record changed back to `10.7.18.254`; cached query returns `10.7.19.246` (TTL 26).
- [x] Sending `SIGHUP` to caching resolver flushes cache; new address `10.7.18.254` appears immediately.
- [x] Evidence file captured and verified: `evidence/dns/ttl-proof.txt`.
- **Verification Result:** **PASSED**

---

### Extension C — Service Isolation (Backend Firewall Rules)
- [x] macOS Packet Filter (PF) rules authored using isolated anchor `com.apple/cnproject`.
- [x] **Mac 1 Policy (`firewall/pf-mac1.conf.example`):**
  - Allows incoming TCP traffic to port 3001 exclusively from Mac 2 (`10.7.18.254`) and loopback.
  - Blocks all other incoming traffic to port 3001.
- [x] **Mac 2 Policy (`firewall/pf-mac2.conf.example`):**
  - Allows Backend B (port 3002) access strictly via loopback (`127.0.0.1:3002`) for local Nginx reverse proxy.
  - Blocks all inbound connections to port 3002 on external interface `en0`.
- [x] **Verification:**
  - Mac 2 localhost Backend B returns healthy.
  - Mac 2 Nginx successfully connects to both backends and serves round-robin load balancing.
  - Mac 1 direct LAN access to `http://10.7.18.254:3002/` times out (`curl: (28) Failed to connect to 10.7.18.254 port 3002 after 3004 ms: Timeout was reached`).
- [x] Safe rollback documented and verified (`sudo pfctl -a com.apple/cnproject -F all`).
- [x] **Topology Limitation Honesty:** Documented that because the team operates 2 physical MacBooks, an independent 3rd external client was not present to probe Backend A unauthorized blocking.
- **Verification Result:** **PASSED WITH TWO-MAC TOPOLOGY LIMITATION**

---

### Extension D — High Availability Backend Failover
- [x] Active Nginx on Mac 2 configured with upstream pool:
  - `server 10.7.19.246:3001 max_fails=1 fail_timeout=10s;` (Backend A)
  - `server 127.0.0.1:3002 max_fails=1 fail_timeout=10s;` (Backend B)
- [x] Passive failure handling configured:
  - `proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;`
- [x] **Failure test:** Backend A process on Mac 1 killed via SSH.
- [x] Six consecutive client requests to `https://app.team1.test:8443/api/status` returned `200 OK` with `X-Backend: B` without client disruption or errors.
- [x] Backend A process restarted; health check returned `{"backend":"A","status":"healthy"}`.
- [x] Subsequent requests verified recovery sequence: `B, B, A, B, A, B, A, B`.
- [x] Single Point of Failure (SPOF) analysis documented: Mac 2 Nginx edge is a SPOF.
- **Verification Result:** **PASSED**

---

### Extension E — Controlled Edge Migration (DNS-Based Cutover)
- [x] Active Edge Nginx running on Mac 2 (`10.7.18.254:8443`).
- [x] Standby Edge Nginx deployed and verified on Mac 1 (`10.7.19.246:8443`).
- [x] Standby edge verified with local Backend A (`127.0.0.1:3001`).
- [x] Controlled DNS cutover applied:
  - `app.team1.test` → `10.7.19.246` (Mac 1 Standby Edge)
  - `api.team1.test` → `10.7.18.254` (Mac 2 Active Edge - unchanged)
- [x] Normal client HTTPS request to `https://app.team1.test:8443` reached Mac 1 and returned Backend A.
- [x] Primary and Backup DNS records synchronized.
- [x] **Honest Status:** DNS cutover and standby edge were verified; simultaneous side-by-side observation of a stale client hitting the old edge while a fresh client hits the new edge is pending separate capture.
- **Verification Result:** **IMPLEMENTED AND MIGRATION VERIFIED; OLD-CACHE/NEW-EDGE OVERLAP EVIDENCE PENDING**

---

### Extension F — Faculty-Injected Troubleshooting Challenge
- [x] Comprehensive diagnostic runbook authored in `docs/troubleshooting.md`.
- [x] Methodological isolation covering Layer 7 (Application), Layer 6/5 (TLS), Layer 4 (TCP), and Layer 3 (DNS/IP).
- [x] Systematic commands and diagnostic matrix prepared for evaluation.
- [x] **Evaluation Status:** Reserved for the live faculty evaluation slot.
- **Verification Result:** **PENDING LIVE FACULTY EVALUATION**
