# Phase 1 — Private Network Service Platform

**Course:** Computer Networks  
**Phase:** 1

## Team Members

| Name | Role |
|------|------|
| Nav Prabhat Singh | Backend B (VM4) · Testing |
| Shivansh Tiwari | Backend A (VM2) · DNS (VM1) · Nginx (VM3) |

---

## Project Architecture

The platform uses four virtual machines.  A private DNS server
resolves a `.test` domain to the Nginx edge VM, which forwards
HTTPS traffic to one of two backend application servers.

```
 Client (browser / curl)
       │
       │  1. DNS query: app.teamX.test?
       ▼
 ┌─────────────┐
 │  VM1  DNS   │  10.7.24.74       dnsmasq
 └─────────────┘
       │
       │  2. Answers: 192.168.64.6
       ▼
 ┌─────────────────────────────┐
 │  VM3  Nginx  :443  (HTTPS)  │  192.168.64.6
 └─────────────────────────────┘
       │
       ├──────────────────────────────────────▶ VM2  Backend A  :3001
       │                                            10.7.24.122
       │
       └──────────────────────────────────────▶ VM4  Backend B  :3002
                                                    10.7.21.116
```

### Component Summary

| VM | Role | Technology |
|----|------|-----------|
| VM1 | Private DNS | dnsmasq |
| VM2 | Backend A | Python (`http.server`) |
| VM3 | HTTPS Edge / Reverse Proxy | Nginx + self-signed TLS |
| VM4 | Backend B | Node.js (`http`) |

---

## Current IP / Service Table

> ⚠️ These are **current lab IPs** assigned by UTM / DHCP.
> They may change when VMs are restarted or the network is reconfigured.
> Update `nginx/app.conf` and `dns/dnsmasq.conf.example` accordingly.

| VM | Role | Current IP | Port |
|----|------|-----------|------|
| VM1 | DNS (dnsmasq) | `10.7.24.74` | 53 |
| VM2 | Backend A (Python) | `10.7.24.122` | 3001 |
| VM3 | Nginx HTTPS edge | `192.168.64.6` | 443 |
| VM4 | Backend B (Node.js) | `10.7.21.116` | 3002 |

---

## Current Known Limitation

> VM3 (Nginx) and the backend VMs are on **different UTM network segments**.
> Because of this, direct connectivity from VM3 to VM4 (Backend B) has
> been **unreliable / timing out** in the current lab environment.
>
> **What works:**
> - Backend A is reachable locally on VM2 and through Nginx (end-to-end verified).
> - Backend B is running and listening on `0.0.0.0:3002` on VM4 (locally verified).
> - Nginx HTTPS is working.
> - Nginx upstream configuration **includes both backends** (`10.7.24.122:3001` and `10.7.21.116:3002`).
>
> **What is pending:**
> - End-to-end Nginx → Backend B path is not yet fully verified due to the cross-segment routing issue.
> - This will be resolved in a later phase / once the UTM network topology is corrected.

---

## DNS Setup (VM1)

VM1 runs `dnsmasq` and answers queries for `*.teamX.test`.
All names resolve to VM3 (Nginx), not directly to the backends.

**Why `.test` and not `.local`:**  
`.local` is reserved by mDNS/Avahi (RFC 6762) and causes conflicts.  
`.test` is the IANA-reserved TLD for exactly this kind of private use (RFC 2606).

### Configure VM1

```bash
# Install dnsmasq
sudo apt install dnsmasq

# Deploy the example config
sudo cp dns/dnsmasq.conf.example /etc/dnsmasq.d/teamX.conf

# Restart
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq
```

### Point clients at VM1

Add to `/etc/resolv.conf` on each client VM:

```
nameserver 10.7.24.74
```

### Test DNS

```bash
dig app.teamX.test @10.7.24.74
nslookup app.teamX.test 10.7.24.74
# Expected: 192.168.64.6
```

---

## Backend A — How to Run (VM2)

Backend A is a pure-Python HTTP server.  No pip dependencies required.

```bash
cd backend-a
python3 server.py
# Backend A running on 0.0.0.0:3001
```

Or use the helper script:

```bash
bash scripts/run-backend-a.sh
```

### Endpoints

| Method | Path | Response |
|--------|------|---------|
| GET | `/` | `200` plain-text greeting |
| GET | `/api/status` | `200` `{"backend":"A","status":"ok"}` |
| ANY | other paths | `404` JSON error |

### Headers on every response

```
X-Backend: A
Cache-Control: max-age=60
```

### Quick test (run on VM2)

```bash
curl -s http://localhost:3001/
curl -s http://localhost:3001/api/status
curl -sI http://localhost:3001/ | grep -E 'X-Backend|Cache-Control'
```

---

## Backend B — How to Run (VM4)

Backend B uses Node.js built-ins only.  No npm install required.

```bash
cd backend-b
node server.js
# Backend B running on 0.0.0.0:3002
```

Or use the helper script:

```bash
bash scripts/run-backend-b.sh
```

### Endpoints

| Method | Path | Response |
|--------|------|---------|
| GET | `/` | `200` `{"backend":"B","message":"Hello from Backend B"}` |
| GET | `/api/status` | `200` `{"backend":"B","status":"ok"}` |
| ANY | other paths | `404` JSON error |

### Headers on every response

```
X-Backend: B
Cache-Control: max-age=60
```

### Quick test (run on VM4)

```bash
curl -s http://localhost:3002/
curl -s http://localhost:3002/api/status
curl -sI http://localhost:3002/ | grep -E 'X-Backend|Cache-Control'
```

---

## Nginx Setup (VM3)

VM3 is the single public entry point.  It terminates HTTPS and
reverse-proxies requests to the backend pool.

### Deploy

```bash
# Copy config
sudo cp nginx/app.conf /etc/nginx/sites-available/app.conf
sudo ln -s /etc/nginx/sites-available/app.conf \
           /etc/nginx/sites-enabled/app.conf

# Place TLS cert and key (generated locally — never committed to git)
sudo mkdir -p /etc/nginx/ssl
sudo cp app.crt /etc/nginx/ssl/app.crt
sudo cp app.key /etc/nginx/ssl/app.key
sudo chmod 600 /etc/nginx/ssl/app.key

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### Generate a self-signed cert (lab use)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout app.key -out app.crt \
  -subj "/CN=app.teamX.test"
```

### Test Nginx

```bash
# Config syntax
sudo nginx -t

# HTTPS works (-k ignores self-signed cert warning)
curl -k https://192.168.64.6/
curl -k https://192.168.64.6/api/status

# Confirm X-Backend header is forwarded
curl -k -sI https://192.168.64.6/ | grep X-Backend
```

---

## Repository Structure

```
phase1-private-network-platform/
├── README.md                          ← you are here
├── .gitignore
├── backend-a/
│   └── server.py                      ← Python backend (Port 3001)
├── backend-b/
│   └── server.js                      ← Node.js backend (Port 3002)
├── nginx/
│   ├── app.conf                       ← Nginx virtual-host + upstream config
│   └── README.md                      ← Nginx deploy guide
├── dns/
│   ├── dnsmasq.conf.example           ← Example dnsmasq config for VM1
│   └── README.md                      ← DNS setup guide
├── scripts/
│   ├── run-backend-a.sh               ← Start Backend A
│   ├── run-backend-b.sh               ← Start Backend B
│   └── test-services.sh               ← Smoke-test both backends
└── docs/
    └── phase1-evidence-checklist.md   ← Demo evidence tracking
```

---

## Security Notes

- **No private keys are committed.** `.key` and `.pem` files are in `.gitignore`.
- **No passwords or secrets** appear anywhere in this repository.
- The `dnsmasq.conf.example` contains only example IPs — update them for your environment.
- The SSL certificate paths in `nginx/app.conf` reference the VM3 local filesystem.

---

## Quick Reference

```bash
# Run smoke tests (on the respective VM)
bash scripts/test-services.sh

# Run Backend A
bash scripts/run-backend-a.sh

# Run Backend B
bash scripts/run-backend-b.sh
```
