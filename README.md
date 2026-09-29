# Private Network Service Platform — Phase 1

**Course:** Computer Networks
**Infrastructure:** Type 2 — 2 physical Macs with combined roles

---

## Team

| Name | Role |
|------|------|
| Nav Prabhat Singh | Mac 1 — DNS + Backend A |
| Shivansh Tiwari | Mac 2 — nginx HTTPS + Backend B |

---

## Architecture

### Machines

| Machine | LAN IP | Services |
|---------|--------|----------|
| Mac 1 | `10.7.15.60` | dnsmasq DNS `:53` · Backend A `:3001` |
| Mac 2 | `10.7.21.116` | nginx HTTPS `:8443` · Backend B `:3002` |

> **Lab IP note:** These are current DHCP leases. They may change between
> sessions. Always run `ifconfig en0` to verify before testing.

### Request Flow

```
Client (Mac 2 or any LAN machine)
  │
  │  1. DNS query (UDP 53)
  ▼
Mac 1  —  dnsmasq :53
  │
  │  app.teamX.test → 10.7.21.116
  │
  ▼
Mac 2  —  nginx :8443 (HTTPS, TLS terminated)
  │
  │  round-robin upstream
  ├──────────────► Mac 1  Backend A :3001
  │
  └──────────────► Mac 2  Backend B :3002

Response: JSON body + X-Backend: A or B + Cache-Control: max-age=60
```

### DNS Records

| Hostname | Resolves To | Target |
|----------|-------------|--------|
| `app.teamX.test` | `10.7.21.116` | Mac 2 nginx |
| `api.teamX.test` | `10.7.21.116` | Mac 2 nginx |

> DNS points to the **nginx proxy**, not directly to the backends.

---

## Backend API

Both backends expose the same endpoints:

| Method | Path | Response |
|--------|------|----------|
| `GET` | `/` | `{"backend":"A"/"B","message":"Hello from Backend A/B"}` |
| `GET` | `/api/status` | `{"backend":"A"/"B","status":"ok","server":"Backend A/B"}` |
| `HEAD` | `/` or `/api/status` | Same headers, no body |

### Response Headers (always present)

| Header | Value |
|--------|-------|
| `X-Backend` | `A` or `B` — identifies which backend handled the request |
| `Cache-Control` | `max-age=60` |
| `Content-Type` | `application/json` |

---

## TLS

nginx on Mac 2 terminates HTTPS on port **8443**.

| Item | Detail |
|------|--------|
| Local CA | TeamX Local Root CA |
| Server cert | `app.crt` (signed by the CA) |
| SAN | `DNS:app.teamX.test`, `DNS:api.teamX.test` |
| Client trust | CA imported into macOS Keychain → `curl` works without `-k` |

See [`tls/README.md`](tls/README.md) for full certificate generation commands.

---

## Verified Commands

All commands below have been tested and produce the documented output.

### DNS

```bash
# Query Mac 1 DNS directly
dig @10.7.15.60 app.teamX.test
dig @10.7.15.60 api.teamX.test

# Query via system resolver (Mac 2 must use Mac 1 as DNS server)
dig app.teamX.test
```

Expected: `ANSWER SECTION` shows `10.7.21.116`; `SERVER: 10.7.15.60#53`

### Backend direct (no nginx, no TLS)

```bash
curl http://10.7.15.60:3001
curl http://10.7.21.116:3002
curl -I http://10.7.15.60:3001/api/status
curl -I http://10.7.21.116:3002/api/status
```

### HTTPS through nginx

```bash
# Full request — no -k needed (CA trusted in Keychain)
curl https://app.teamX.test:8443/api/status

# Headers only
curl -I https://app.teamX.test:8443/api/status
```

Expected response:
```
HTTP/1.1 200 OK
X-Backend: A          ← or B, depending on round-robin turn
Cache-Control: max-age=60
Content-Type: application/json
```

### Load balancing (round-robin verification)

```bash
for i in {1..10}; do
    echo -n "Request $i: "
    curl -s -D - https://app.teamX.test:8443/api/status \
        -o /dev/null | grep -i "X-Backend"
done
```

Expected: `X-Backend: A` and `X-Backend: B` alternating.

### nginx config validation

```bash
nginx -t
```

---

## Setup Instructions

### Prerequisites

Both Macs must be on the same Wi-Fi LAN.

Install Homebrew tools on each Mac:

```bash
# Install Python (if not already present via Xcode tools)
brew install python

# Mac 1 — install dnsmasq
brew install dnsmasq

# Mac 2 — install nginx
brew install nginx
```

---

### Mac 1 Setup (DNS + Backend A)

#### 1. Configure dnsmasq

```bash
# Find the config file location
brew info dnsmasq | grep -A3 "Caveats"
# Typically: /opt/homebrew/etc/dnsmasq.conf  (Apple Silicon)
#            /usr/local/etc/dnsmasq.conf      (Intel)

# Copy the example config
sudo cp dns/dnsmasq.conf.example /opt/homebrew/etc/dnsmasq.conf

# Edit to confirm your LAN IP:
#   listen-address=127.0.0.1,<MAC1_IP>
#   address=/app.teamX.test/<MAC2_IP>
#   address=/api.teamX.test/<MAC2_IP>
```

#### 2. Start dnsmasq

```bash
sudo brew services start dnsmasq
# Check it is listening:
sudo lsof -nP -i :53 | grep dnsmasq
```

#### 3. Run Backend A

```bash
# From the repo root:
bash scripts/run-backend-a.sh

# Or directly:
cd backend-a
python3 server.py
```

Verify: `curl http://10.7.15.60:3001`

---

### Mac 2 Setup (nginx HTTPS + Backend B)

#### 1. Configure Mac 2 DNS to point to Mac 1

```bash
# Set Mac 1 as the DNS server for Wi-Fi
networksetup -setdnsservers "Wi-Fi" 10.7.15.60

# Flush DNS cache
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Verify
networksetup -getdnsservers "Wi-Fi"
# Expected: 10.7.15.60
```

#### 2. Set up TLS certificates

```bash
mkdir -p ~/cn-project/nginx/ssl

# Generate CA + server cert (see tls/README.md for full commands)
# Place app.crt and app.key in ~/cn-project/nginx/ssl/
# NEVER commit app.key or teamX-rootCA.key

# Trust the CA in macOS Keychain:
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain teamX-rootCA.crt
```

#### 3. Deploy nginx config

```bash
# Copy phase1.conf and update USERNAME and paths:
cp nginx/phase1.conf /opt/homebrew/etc/nginx/servers/phase1.conf
# Edit ssl_certificate / ssl_certificate_key paths to match your home dir

# Validate:
nginx -t

# Start nginx:
brew services start nginx
# Or reload if already running:
nginx -s reload
```

#### 4. Run Backend B

```bash
bash scripts/run-backend-b.sh

# Or directly:
cd backend-b
python3 server.py
```

Verify: `curl http://10.7.21.116:3002`

#### 5. Full end-to-end test

```bash
curl https://app.teamX.test:8443/api/status
curl -I https://app.teamX.test:8443/api/status
bash scripts/test-load-balancing.sh
```

---

## Security

| Rule | Detail |
|------|--------|
| Never commit `*.key` | Private keys are blocked by `.gitignore` |
| Never commit `*.csr` or `*.srl` | Also blocked by `.gitignore` |
| No passwords or secrets in source | Verified — all configs use placeholder values |
| CA private key stays local | `teamX-rootCA.key` lives only on Mac 2 |

---

## Repository Structure

```
.
├── README.md
├── .gitignore
├── backend-a/
│   └── server.py              Python HTTP server, port 3001
├── backend-b/
│   └── server.py              Python HTTP server, port 3002
├── nginx/
│   ├── phase1.conf            Working nginx config (USERNAME placeholder)
│   └── phase1.conf.example    Generic template with all placeholders
├── dns/
│   └── dnsmasq.conf.example   dnsmasq template
├── tls/
│   └── README.md              CA architecture, cert generation, trust setup
├── scripts/
│   ├── run-backend-a.sh
│   ├── run-backend-b.sh
│   ├── test-backends.sh       Direct IP tests
│   ├── test-dns.sh            dig tests
│   ├── test-https.sh          curl HTTPS (no -k)
│   └── test-load-balancing.sh 10-request round-robin demo
├── docs/
│   ├── architecture.md        Topology, protocol stack, flow diagrams
│   └── phase1-checklist.md    Verified vs. pending evidence
└── evidence/
    ├── README.md
    ├── dns/                   dig output, screenshots
    ├── https/                 curl output, cert screenshots
    ├── load-balancing/        round-robin terminal output
    ├── caching/               Cache-Control / 304 evidence
    ├── wireshark/             Wireshark screenshots
    └── failures/              Error/failure demonstrations
```
