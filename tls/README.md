# TLS & Certificate Authority (CA) Architecture

## Overview

This project implements transport-layer encryption using a **locally trusted Certificate Authority (CA)** (created via `mkcert` or OpenSSL).

By trusting the local Root CA in the client operating system trust store (macOS Keychain), all `curl` and web browser requests connect securely **without using `-k` / `--insecure`**.

---

## Certificate Trust Hierarchy

```
Local Root CA (mkcert / Local CA)
└── edge-cert.pem (Server certificate)
    ├── Subject CN: app.team1.test
    └── Subject Alternative Names (SAN):
        ├── DNS:app.team1.test
        └── DNS:api.team1.test
```

### Security & Certificate Specification

| Parameter | Value |
|-----------|-------|
| Root CA File | `certs/rootCA.pem` (Public certificate; may be shared) |
| Root CA Private Key | `rootCA-key.pem` (**NEVER committed; strictly local**) |
| Edge Certificate | `certs/edge-cert.pem` (Public server certificate) |
| Edge Private Key | `certs/edge-key.pem` (**NEVER committed; strictly local**) |
| Valid Domains (SAN) | `app.team1.test`, `api.team1.test` |
| Edge Port | `8443` (Non-privileged TLS listener) |
| Supported Protocols | TLSv1.2, TLSv1.3 |

---

## Why Use a Trusted Local CA Instead of Self-Signed Certificates?

A single self-signed certificate generates validation warnings in browsers and forces tools like `curl` to use `-k` (insecure mode), which disables certificate chain validation entirely.

By establishing a local Root CA and importing it into the system trust store:
1. The client validates the cryptographic signature of `edge-cert.pem`.
2. The client confirms the hostname in the URL matches the certificate's Subject Alternative Names (SAN).
3. The connection is authentic and protected against MITM attacks on the LAN.
4. **No `-k` flag is needed in any demo command.**

---

## Installation & Trust Setup

### Option A: Using `mkcert` (Recommended)

1. Install `mkcert` on Mac 1 and Mac 2:
   ```bash
   brew install mkcert
   brew install nss # optional, for Firefox
   ```

2. Install local CA into system trust store:
   ```bash
   mkcert -install
   ```

3. Generate certificate covering both project domains:
   ```bash
   mkcert -cert-file certs/edge-cert.pem -key-file certs/edge-key.pem app.team1.test api.team1.test
   ```

4. Distribute the Root CA certificate (`rootCA.pem`) to the other Mac and trust it:
   ```bash
   sudo security add-trusted-cert -d -r trustRoot \
     -k /Library/Keychains/System.keychain certs/rootCA.pem
   ```

---

### Option B: Using Standard OpenSSL (Alternative)

```bash
# 1. Generate Root CA key and certificate
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 \
  -subj "/CN=Team1 Local Root CA" -out rootCA.pem

# 2. Generate Server private key and CSR
openssl genrsa -out edge-key.pem 2048
openssl req -new -key edge-key.pem -subj "/CN=app.team1.test" -out edge.csr

# 3. Create SAN extension file
cat > san.ext <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = app.team1.test
DNS.2 = api.team1.test
EOF

# 4. Sign server certificate with Root CA
openssl x509 -req -in edge.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial \
  -days 365 -sha256 -extfile san.ext -extensions v3_req -out edge-cert.pem

# 5. Trust Root CA on macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain rootCA.pem
```

---

## Verification Commands

```bash
# 1. Inspect Subject and SANs
openssl x509 -in certs/edge-cert.pem -text -noout | grep -A2 "Subject Alternative Name"

# 2. Test HTTPS without -k
curl -v https://app.team1.test:8443/api/status
```
Expected: `SSL certificate verify ok.`
