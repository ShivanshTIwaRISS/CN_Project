# Evidence Directory

This directory holds captured proof of the working Phase 1 infrastructure.

> **Do not fabricate evidence.** Only add files that were actually captured
> during testing. Unfilled folders are intentional — they mark items still
> pending capture.

---

## Folder Guide

| Folder | What to put here |
|--------|-----------------|
| `dns/` | `dig` terminal output (`.txt`), DNS screenshots |
| `https/` | `curl` and `curl -I` output (`.txt`), browser screenshots showing valid cert |
| `load-balancing/` | Terminal output showing `X-Backend: A` / `X-Backend: B` alternating |
| `caching/` | `curl -I` output showing `Cache-Control: max-age=60`; 304 evidence if captured |
| `wireshark/` | Wireshark screenshots (`.png`); **note:** `.pcapng` binary files are in `.gitignore` — host them externally |
| `failures/` | Curl error output when CA not trusted, DNS fails, or a backend is stopped |

---

## Naming Convention

Use descriptive names, e.g.:

```
dns/dig-app-teamX-test.txt
dns/dig-api-teamX-test.txt
https/curl-api-status-200.txt
https/curl-I-headers.txt
load-balancing/round-robin-10-requests.txt
caching/cache-control-header.txt
wireshark/dns-query-response.png
wireshark/tls-handshake.png
failures/curl-no-ca-trust-error.txt
failures/backend-a-stopped-nginx-error.txt
```

---

## Current Status

See [`docs/phase1-checklist.md`](../docs/phase1-checklist.md) for a full
list of what is verified vs. pending.
