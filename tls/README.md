# TLS — TeamX Local CA Architecture

## Overview

This project uses a **local Certificate Authority (CA)** rather than a
self-signed server certificate. This means the final `curl` tests run
**without `-k`** — the certificate chain is fully trusted.

---

## Certificate Hierarchy

```
TeamX Local Root CA
└── app.crt  (server certificate for app.teamX.test)
```

| Item | Detail |
|------|--------|
| CA name | `TeamX Local Root CA` |
| CA key | `teamX-rootCA.key` — **NEVER commit this** |
| CA cert | `teamX-rootCA.crt` — public, may be shared |
| Server cert | `app.crt` |
| Server key | `app.key` — **NEVER commit this** |
| Subject CN | `app.teamX.test` |
| SAN | `DNS:app.teamX.test`, `DNS:api.teamX.test` |
| nginx TLS port | **8443** (443 not used — non-privileged port) |

---

## Why a Local CA?

A directly self-signed server certificate would require `-k` on every `curl`
call because curl cannot build a chain of trust. By creating a local root CA
and trusting it on the client machine, curl sees a valid chain:

```
client trust store
  └── TeamX Local Root CA   (trusted by macOS Keychain / curl --cacert)
        └── app.crt          (verified)
```

---

## TLS Handshake Flow (simplified)

```
Client (Mac 2 curl)               nginx (Mac 2 :8443)
─────────────────────────────────────────────────────
ClientHello  ─────────────────────────────>
                         <─────────────── ServerHello
                         <─────────────── Certificate (app.crt)
                         <─────────────── ServerHelloDone
ClientKeyExchange ────────────────────────>
ChangeCipherSpec ─────────────────────────>
Finished ─────────────────────────────────>
                         <─────────────── ChangeCipherSpec
                         <─────────────── Finished
──── Encrypted application data (HTTP/1.1) ──────────
GET /api/status HTTP/1.1 ─────────────────>
                         <─────────────── 200 OK + JSON
```

---

## Regeneration Commands (reference only)

> **Do not run these unless regenerating certificates.**
> The actual keys live on Mac 2 outside the repository.

### 1 — Create the local Root CA

```bash
# Generate CA private key (keep secret, never commit)
openssl genrsa -out teamX-rootCA.key 2048

# Self-sign the CA certificate (10-year validity, lab use)
openssl req -x509 -new -nodes \
    -key teamX-rootCA.key \
    -sha256 -days 3650 \
    -subj "/CN=TeamX Local Root CA" \
    -out teamX-rootCA.crt
```

### 2 — Create the server certificate signed by the CA

```bash
# Create a SAN extension file
cat > san.ext <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = app.teamX.test
DNS.2 = api.teamX.test
EOF

# Generate server private key (keep secret, never commit)
openssl genrsa -out app.key 2048

# Create CSR
openssl req -new \
    -key app.key \
    -subj "/CN=app.teamX.test" \
    -out app.csr

# Sign with the CA, embedding SANs
openssl x509 -req \
    -in app.csr \
    -CA teamX-rootCA.crt \
    -CAkey teamX-rootCA.key \
    -CAcreateserial \
    -days 365 \
    -sha256 \
    -extfile san.ext \
    -extensions v3_req \
    -out app.crt
```

### 3 — Verify the chain

```bash
openssl verify -CAfile teamX-rootCA.crt app.crt
# Expected output:  app.crt: OK
```

### 4 — Inspect the certificate

```bash
openssl x509 -in app.crt -text -noout | grep -A4 "Subject\|SAN\|Issuer"
```

### 5 — Trust the CA on the client Mac

```bash
# Import into macOS Keychain (run once per machine)
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain teamX-rootCA.crt
```

---

## Files NOT in this repository

| File | Reason |
|------|--------|
| `app.key` | Server private key — listed in `.gitignore` |
| `teamX-rootCA.key` | CA private key — listed in `.gitignore` |
| `app.csr` | Certificate signing request — listed in `.gitignore` |
| `*.srl` | CA serial file — listed in `.gitignore` |

The `app.crt` and `teamX-rootCA.crt` public certificates may be stored
in the repo for reference, but are not required to be checked in.

---

## Final verification (no `-k`)

```bash
# After trusting the CA in macOS Keychain:
curl https://app.teamX.test:8443/api/status
curl -I https://app.teamX.test:8443/api/status
```

Expected: `HTTP/1.1 200 OK` with no certificate error.
