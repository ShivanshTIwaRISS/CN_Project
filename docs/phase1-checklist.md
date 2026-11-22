# Phase 1 Evidence Checklist — Private Network Service Platform

> **Status Key:**
> - ✅ VERIFIED — Fully implemented, tested, and evidence documented
> - ⚠️ LIMITATION / PENDING — Specific physical topology limitation or reserved live evaluation

---

## 1. Physical LAN & Infrastructure

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 1 | LAN IP inventory (Mac 1 & Mac 2) | ✅ VERIFIED | Mac 1 (`10.7.19.246`), Mac 2 (`10.7.18.254`) on `en0` via `ifconfig en0` |
| 2 | Bidirectional Ping Reachability | ✅ VERIFIED | 0.0% packet loss between Mac 1 and Mac 2 across private Wi-Fi subnet |
| 3 | Documented 2-Mac Topology | ✅ VERIFIED | Documented in `docs/architecture.md` with combined logical roles |

---

## 2. Private DNS Resolution

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 4 | Primary DNS resolves `app.team1.test` | ✅ VERIFIED | `dig @10.7.19.246 app.team1.test` returns `10.7.18.254` (TTL 30) |
| 5 | Primary DNS resolves `api.team1.test` | ✅ VERIFIED | `dig @10.7.19.246 api.team1.test` returns `10.7.18.254` (TTL 30) |
| 6 | Client uses Mac 1 as DNS resolver | ✅ VERIFIED | Configured via `networksetup -setdnsservers "Wi-Fi" 10.7.19.246` |
| 7 | Unqualified DNS lookup (no `@`) | ✅ VERIFIED | `dig app.team1.test` successfully answers via local DNS server |
| 8 | Negative DNS proof on public resolver | ✅ VERIFIED | `dig @8.8.8.8 app.team1.test` returns `NXDOMAIN` (isolated namespace) |

---

## 3. Backend HTTP REST Services

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 9 | Backend A responds on port 3001 | ✅ VERIFIED | Direct query: `curl http://10.7.19.246:3001/` returns JSON |
| 10 | Backend B responds on port 3002 | ✅ VERIFIED | Direct query: `curl http://10.7.18.254:3002/` returns JSON |
| 11 | Backend Identifier Header (`X-Backend`) | ✅ VERIFIED | `X-Backend: A` and `X-Backend: B` present in HTTP response headers |
| 12 | Health & Status Endpoints | ✅ VERIFIED | `/api/status` returns status ok; `/health` returns healthy |
| 13 | Dual-Runtime Compatibility | ✅ VERIFIED | Both Python (`server.py`) and Node.js (`server.js`) runtimes tested |

---

## 4. Edge Reverse Proxy & Load Balancer

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 14 | Nginx syntax check passes | ✅ VERIFIED | `nginx -t` reports syntax OK |
| 15 | Nginx listens on port 8443 | ✅ VERIFIED | `lsof -nP -i :8443` confirms listening socket on Mac 2 |
| 16 | Reverse proxy routing | ✅ VERIFIED | Requests to `https://app.team1.test:8443/` reach upstream pool |
| 17 | Round-Robin Load Balancing | ✅ VERIFIED | Repeated `curl` requests alternate between `X-Backend: A` and `X-Backend: B` |
| 18 | Client abstraction | ✅ VERIFIED | Client accesses backends solely through domain and port 8443 |

---

## 5. HTTPS / TLS Termination & Trust

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 19 | Trusted local Certificate Authority | ✅ VERIFIED | Root CA generated via mkcert/local CA and installed in macOS Keychain |
| 20 | HTTPS without insecure bypass (`-k`) | ✅ VERIFIED | `curl https://app.team1.test:8443/api/status` succeeds without `-k` |
| 21 | Subject Alternative Names (SAN) | ✅ VERIFIED | Certificate covers both `app.team1.test` and `api.team1.test` |
| 22 | TLS protocol & cipher suite | ✅ VERIFIED | Negotiated TLS 1.2 / TLS 1.3 with AEAD cipher |
| 23 | Private key security | ✅ VERIFIED | `*.key`, `*.pem`, `*.csr` excluded in `.gitignore` and kept local |

---

## 6. HTTP Caching & Transport Layer

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 24 | Cache-Control Header present | ✅ VERIFIED | `/api/info` returns `Cache-Control: public, max-age=30` (or `max-age=60`) |
| 25 | ETag & Conditional Requests | ✅ VERIFIED | Server returns `ETag`; conditional `If-None-Match` returns `304 Not Modified` |
| 26 | TCP Handshake verification | ✅ VERIFIED | SYN -> SYN-ACK -> ACK captured on port 8443 |
| 27 | TLS Handshake verification | ✅ VERIFIED | ClientHello, ServerHello, Certificate, Finished frames verified |
| 28 | Encrypted application data | ✅ VERIFIED | HTTP application data confirmed fully encrypted on the wire |

---

## 7. Baseline Failure Demonstrations

| # | Check Item | Status | Verification Detail / Observed Output |
|---|------------|--------|---------------------------------------|
| 29 | DNS removal failure mode | ✅ VERIFIED | Clearing DNS servers causes `curl: (6) Could not resolve host` |
| 30 | Backend isolation failure mode | ✅ VERIFIED | Stopping single backend activates graceful failover (Phase 2 Ext D) |
