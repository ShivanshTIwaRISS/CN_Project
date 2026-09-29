# Architecture — Phase 1 Private Network Service Platform

## Infrastructure Type

**Type 2 — 2 physical Macs with combined roles**

Each Mac runs multiple project components simultaneously.

---

## Machine / IP / Service Table

| Machine | LAN IP | Interface | Services |
|---------|--------|-----------|----------|
| Mac 1 | `10.7.15.60` | `en0` (Wi-Fi) | dnsmasq DNS :53 · Backend A :3001 |
| Mac 2 | `10.7.21.116` | `en0` (Wi-Fi) | nginx HTTPS :8443 · Backend B :3002 |

> **Lab IP note:** These addresses are current DHCP leases on the shared LAN.
> They may change if either Mac is rebooted or reconnects. Always verify with
> `ifconfig en0` before testing.

---

## ASCII Topology

```
          ┌─────────────────────────────────────────┐
          │              Shared LAN                 │
          │         (Wi-Fi, 10.7.0.0/16)            │
          └─────────────────────────────────────────┘
                │                        │
       ┌────────┴──────────┐    ┌────────┴──────────────┐
       │      Mac 1        │    │        Mac 2           │
       │   10.7.15.60      │    │    10.7.21.116         │
       │                   │    │                        │
       │  ┌─────────────┐  │    │  ┌──────────────────┐  │
       │  │  dnsmasq    │  │    │  │  nginx :8443     │  │
       │  │  UDP/TCP 53 │  │    │  │  (HTTPS / TLS)   │  │
       │  └─────────────┘  │    │  └──────┬───────────┘  │
       │                   │    │         │               │
       │  ┌─────────────┐  │    │  ┌──────┴───────────┐  │
       │  │  Backend A  │◄─┼────┼──┤  upstream pool   │  │
       │  │  Python     │  │    │  │  round-robin     │  │
       │  │  TCP 3001   │  │    │  └──────┬───────────┘  │
       │  └─────────────┘  │    │         │               │
       │                   │    │  ┌──────┴───────────┐  │
       └───────────────────┘    │  │  Backend B       │  │
                                │  │  Python          │  │
                                │  │  TCP 3002        │  │
                                │  └──────────────────┘  │
                                └────────────────────────┘

  Client (any machine on LAN)
      │
      │ 1. DNS query (UDP 53)
      ▼
  Mac 1 dnsmasq  ──► app.teamX.test → 10.7.21.116
      │
      │ 2. resolved IP returned
      ▼
  Client sends HTTPS request (TCP 8443)
      │
      ▼
  Mac 2 nginx :8443  (TLS termination, SNI: app.teamX.test)
      │
      │  round-robin upstream
      ├──────────────► Mac 1 Backend A :3001  (HTTP plain)
      │
      └──────────────► Mac 2 Backend B :3002  (HTTP plain)

  Response includes:
      X-Backend: A  or  X-Backend: B
      Cache-Control: max-age=60
```

---

## Protocol Stack Mapping

| Layer | Protocol | Detail |
|-------|----------|--------|
| Application | HTTP/1.1 | GET / · GET /api/status |
| Presentation | TLS 1.2/1.3 | Terminated at nginx on Mac 2 |
| Transport | TCP | :8443 (nginx) · :3001 (A) · :3002 (B) |
| Network | IPv4 | 10.7.0.0/16 LAN |
| DNS | UDP 53 | dnsmasq on Mac 1 |

---

## Component Descriptions

### DNS — dnsmasq on Mac 1

- Listens on `127.0.0.1` and `10.7.15.60`, port 53.
- Maintains a private `.test` zone:
  - `app.teamX.test` → `10.7.21.116`
  - `api.teamX.test` → `10.7.21.116`
- All other queries are forwarded to `1.1.1.1` / `8.8.8.8`.
- `.test` is used intentionally (RFC 6761 reserved). `.local` is forbidden
  (macOS uses it for mDNS/Bonjour).

### TLS — nginx on Mac 2

- nginx listens on port **8443** (non-privileged, no `sudo` needed).
- TLS is terminated at nginx. Backend communication is plain HTTP.
- Certificate: `app.crt`, signed by **TeamX Local Root CA**.
- SAN covers both `app.teamX.test` and `api.teamX.test`.
- The root CA is trusted in macOS Keychain on Mac 2, enabling `curl` without
  `-k`.

### Load Balancing — nginx upstream

- nginx uses the default **round-robin** policy.
- Both backends are in the upstream pool:
  - `10.7.15.60:3001` — Backend A
  - `10.7.21.116:3002` — Backend B
- Each response carries `X-Backend: A` or `X-Backend: B` so the rotating
  backend is observable.

### Backend A — Python on Mac 1

- Pure Python `http.server` module, no external dependencies.
- Port 3001, bound to `0.0.0.0`.
- Returns JSON with `"backend": "A"`.
- Sets `X-Backend: A` and `Cache-Control: max-age=60`.

### Backend B — Python on Mac 2

- Identical structure to Backend A.
- Port 3002, bound to `0.0.0.0`.
- Returns JSON with `"backend": "B"`.
- Sets `X-Backend: B` and `Cache-Control: max-age=60`.

---

## DNS Resolution Flow (detailed)

```
1. curl on Mac 2 tries to connect to app.teamX.test:8443
2. macOS stub resolver checks /etc/resolv.conf → sees 10.7.15.60
3. macOS sends DNS query: A app.teamX.test ? to 10.7.15.60:53 (UDP)
4. dnsmasq on Mac 1 matches address=/app.teamX.test/10.7.21.116
5. dnsmasq replies: app.teamX.test → 10.7.21.116, TTL 0
6. curl connects to 10.7.21.116:8443 via TCP
7. TLS handshake: curl presents no cert; nginx sends app.crt
8. curl verifies app.crt via trusted TeamX Local Root CA in Keychain
9. Encrypted HTTP request sent over TLS
10. nginx proxies to one of the backends (plain HTTP)
11. Backend returns JSON + X-Backend header
12. nginx forwards response to curl over TLS
```
