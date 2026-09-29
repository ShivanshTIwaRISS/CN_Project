# Phase 1 Evidence Checklist

> **Key:**
> - ✅ VERIFIED — tested and documented below
> - ⬜ PENDING — not yet captured / evidence not yet in repo

---

## Infrastructure

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | LAN IP inventory (Mac 1, Mac 2) | ✅ VERIFIED | `ifconfig en0` on both Macs |
| 2 | Ping between Mac 1 and Mac 2 | ⬜ PENDING | capture screenshot/output |

---

## DNS

| # | Item | Status | Notes |
|---|------|--------|-------|
| 3 | `dig @10.7.15.60 app.teamX.test` returns `10.7.21.116` | ✅ VERIFIED | tested on Mac 2 |
| 4 | `dig @10.7.15.60 api.teamX.test` returns `10.7.21.116` | ✅ VERIFIED | tested on Mac 2 |
| 5 | Mac 2 uses Mac 1 as DNS server | ✅ VERIFIED | `networksetup -getdnsservers "Wi-Fi"` → `10.7.15.60` |
| 6 | `dig app.teamX.test` resolves via `10.7.15.60#53` (no `@`) | ✅ VERIFIED | system resolver working |

---

## Backend Services

| # | Item | Status | Notes |
|---|------|--------|-------|
| 7 | Backend A responds on `10.7.15.60:3001` | ✅ VERIFIED | `curl http://10.7.15.60:3001` |
| 8 | Backend B responds on `10.7.21.116:3002` | ✅ VERIFIED | `curl http://10.7.21.116:3002` |
| 9 | Both backends return `X-Backend` header | ✅ VERIFIED | observed in `-I` output |
| 10 | Both backends return `Cache-Control: max-age=60` | ✅ VERIFIED | observed in header output |

---

## nginx / HTTPS

| # | Item | Status | Notes |
|---|------|--------|-------|
| 11 | `nginx -t` passes | ✅ VERIFIED | config syntax OK |
| 12 | nginx listens on port 8443 | ✅ VERIFIED | confirmed on Mac 2 |
| 13 | HTTPS trusted **without** `-k` | ✅ VERIFIED | TeamX Local Root CA trusted in Keychain |
| 14 | `curl https://app.teamX.test:8443/api/status` succeeds | ✅ VERIFIED | 200 OK |
| 15 | Response headers include `X-Backend` and `Cache-Control` | ✅ VERIFIED | `curl -I` confirmed |

---

## Load Balancing

| # | Item | Status | Notes |
|---|------|--------|-------|
| 16 | Round-robin distributes across both backends | ✅ VERIFIED | `X-Backend: A` and `X-Backend: B` alternating in repeated requests |

---

## TLS Certificate

| # | Item | Status | Notes |
|---|------|--------|-------|
| 17 | `openssl verify -CAfile teamX-rootCA.crt app.crt` → `OK` | ✅ VERIFIED | chain verified |
| 18 | SAN includes `app.teamX.test` and `api.teamX.test` | ✅ VERIFIED | from cert inspection |

---

## Caching Evidence

| # | Item | Status | Notes |
|---|------|--------|-------|
| 19 | `Cache-Control: max-age=60` header present on responses | ✅ VERIFIED | seen in `curl -I` output |
| 20 | Actual cache hit / 304 Not Modified demonstration | ⬜ PENDING | needs screenshot or curl output saved to `evidence/caching/` |

---

## Wireshark Captures

| # | Item | Status | Notes |
|---|------|--------|-------|
| 21 | DNS query/response capture | ⬜ PENDING | save `.pcapng` to `evidence/wireshark/` |
| 22 | TCP 3-way handshake capture | ⬜ PENDING | save `.pcapng` to `evidence/wireshark/` |
| 23 | TLS ClientHello / ServerHello capture | ⬜ PENDING | save `.pcapng` to `evidence/wireshark/` |
| 24 | Encrypted HTTP data capture | ⬜ PENDING | save `.pcapng` to `evidence/wireshark/` |

> Note: `.pcapng` files are listed in `.gitignore` (binary, large).
> Upload captures as GitHub release assets or store externally.

---

## Failure Demonstrations

| # | Item | Status | Notes |
|---|------|--------|-------|
| 25 | Curl fails with wrong domain / no DNS | ⬜ PENDING | save output to `evidence/failures/` |
| 26 | Curl fails when CA not trusted (before Keychain trust) | ⬜ PENDING | save output to `evidence/failures/` |
| 27 | Backend A or B stopped → nginx returns error or reduced LB | ⬜ PENDING | save output to `evidence/failures/` |

---

## Final Presentation

| # | Item | Status | Notes |
|---|------|--------|-------|
| 28 | Screenshots in `evidence/` subfolders | ⬜ PENDING |  |
| 29 | Topology diagram (matches actual setup) | ✅ VERIFIED | see `docs/architecture.md` |
| 30 | Final live demo / video | ⬜ PENDING |  |
