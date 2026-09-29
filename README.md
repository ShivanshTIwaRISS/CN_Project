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

## Packet Analysis & Verification Evidence

All infrastructure components and network protocol flows were captured and validated using terminal logs and Wireshark network packet traces (`wireshark_Wi-FiL0A0v3.pcapng`).

### 1. Toolchain & Backend B Server Execution

Terminal verification showing Homebrew installations, software versions, and Backend B (`server.py`) handling live traffic:

```text
==> Pouring openssl@4--4.0.2_1.arm64_sequoia.bottle.tar.gz
==> Installing nginx
==> Pouring nginx--1.31.6.arm64_sequoia.bottle.tar.gz

> nginx -v
nginx version: nginx/1.31.6

> python3 --version
Python 3.14.7

> openssl version
OpenSSL 4.0.2 25 Aug 2026 (Library: OpenSSL 4.0.2 25 Aug 2026)

> python3 ~/cn-project/backend-b/server.py
Backend B running on 0.0.0.0:3002
[Backend B] 127.0.0.1 - "GET / HTTP/1.1" 200 -
[Backend B] 127.0.0.1 - "GET /api/status HTTP/1.1" 200 -
[Backend B] 10.7.21.116 - "HEAD /api/status HTTP/1.1" 200 -
[Backend B] 10.7.21.116 - "GET /api/status HTTP/1.1" 200 -
[Backend B] 10.7.21.116 - "GET / HTTP/1.1" 200 -
```

**Key Highlights:**
- **Software Stack:** Nginx 1.31.6, Python 3.14.7, OpenSSL 4.0.2 verified.
- **Backend B Service:** Successfully runs on `0.0.0.0:3002`, answering both `GET` and `HEAD` requests with `200 OK` and sending proper custom headers (`X-Backend: B`, `Cache-Control: max-age=60`).

---

### 2. Wireshark HTTPS & TLS Session Capture (`tcp.port == 8443`)

Wireshark display filter: `tcp.port == 8443` captures full HTTPS session interactions between client `10.7.15.60` (Mac 1) and Nginx reverse proxy `10.7.21.116:8443` (Mac 2):

```
Client (10.7.15.60)                                   Nginx Server (10.7.21.116:8443)
      │                                                              │
      │ ── Frame 9692: [SYN, ECE, CWR] Seq=0 Win=65535 MSS=1460 ───> │ (TCP Handshake Step 1)
      │ <─ Frame 9693: [SYN, ACK] Seq=0 Ack=1 Win=65535 MSS=1460 ──── │ (TCP Handshake Step 2)
      │ ── Frame 9694: [ACK] Seq=1 Ack=1 ──────────────────────────> │ (TCP Handshake Step 3)
      │                                                              │
      │ ── Frame 9695: TLS Client Hello (SNI=app.teamx.test) ──────> │ (TLS Handshake & SNI)
      │ <─ Frame 9696: [ACK] Seq=1 Ack=325 ───────────────────────── │
      │ <─ Frame 9697: Server Hello, Change Cipher Spec, App Data ── │ (Cert Exchange & Cipher Setup)
      │                                                              │
      │ ── Frame 9698: [ACK] Seq=325 Ack=1653 ─────────────────────> │
      │ ── Frame 9716: Application Data (Encrypted HTTP Request) ──> │ (Encrypted HTTPS Traffic)
      │ ── Frame 9717: [RST, ACK] Seq=349 Ack=1653 Win=130752 ─────> │ (Client Session Teardown)
```

**Analysis & Protocol Observations:**
1. **TCP 3-Way Handshake:** Clean SYN, SYN-ACK, ACK handshake on destination port 8443 with Window Scale `WS=64` and Maximum Segment Size `MSS=1460`.
2. **TLS 1.2/1.3 Handshake & SNI Extension:** Packet 9695 clearly shows the `Client Hello` carrying Server Name Indication (`SNI=app.teamx.test`), ensuring Nginx matches the correct virtual host and returns the local CA-signed `app.crt`.
3. **Encrypted Payload Exchange:** Subsequent packets exchange TLS `Application Data` without exposing plaintext HTTP methods, endpoints, or response bodies over the local network.

---

### 3. Wireshark HTTP Request & Response Statistics

Wireshark HTTP Protocol Packet Counter statistics breakdown:

| Metric | Count | Percentage | Details |
|--------|-------|------------|---------|
| **Total HTTP Packets** | **8** | 100% | Direct unencrypted backend traffic |
| **HTTP Response Packets** | **4** | 50.00% | All responses from upstream backends |
| ↳ `2xx: Success (200 OK)` | 4 | 100.00% | 0% errors (no 4xx/5xx failures) |
| **HTTP Request Packets** | **4** | 50.00% | Inbound backend queries |
| ↳ `GET` Requests | 4 | 100.00% | API status & health probes |

**Analysis:**
- Confirms 100% success rate (`200 OK`) across direct backend tests without dropped connections or gateway errors.

---

### 4. TCP Handshake Analysis — SYN Flag Filtering (`tcp.flags.syn == 1 && tcp.flags.ack == 0`)

Wireshark display filter: `tcp.flags.syn == 1 && tcp.flags.ack == 0`

- **Purpose:** Isolates initial TCP connection initiation requests (packets with SYN bit set and ACK bit cleared).
- **Observed Behavior:**
  - Client `10.7.15.60` initiates outbound TCP connections to ports `443` (HTTPS) and `80` (HTTP).
  - Packet headers show `Len=0`, initial `Seq=0`, initial window size `Win=65535`, `MSS=1460`, `WS=64`, and `SACK_PERM` (Selective Acknowledgement Permitted).
  - Demonstrates standard TCP state machine initiation across client applications.

---

### 5. TCP Handshake Analysis — SYN-ACK Flag Filtering (`tcp.flags.syn == 1 && tcp.flags.ack == 1`)

Wireshark display filter: `tcp.flags.syn == 1 && tcp.flags.ack == 1`

- **Purpose:** Isolates server responses acknowledging connection requests and completing the second leg of the TCP 3-way handshake.
- **Observed Behavior:**
  - **Backend A Port 3001:** Packet 52856 captures `10.7.15.60:3001 -> 10.7.21.116:51789 [SYN, ACK]`, confirming Backend A is reachable and actively accepting inbound sockets.
  - **Nginx HTTPS Port 8443:** Multiple SYN-ACK response frames from `10.7.21.116:8443` to `10.7.15.60`, confirming TLS listener responsiveness.
  - **Service Readiness:** Confirms bidirectional network connectivity and open listener sockets across ports `3001`, `3002`, and `8443`.

---

### 6. Physical LAN Connectivity (ICMP Ping Test)

Verification of physical Layer 3 connectivity across the local Wi-Fi network:

```bash
> ping -c 4 10.7.15.60
PING 10.7.15.60 (10.7.15.60): 56 data bytes
64 bytes from 10.7.15.60: icmp_seq=0 ttl=64 time=29.203 ms
64 bytes from 10.7.15.60: icmp_seq=1 ttl=64 time=49.266 ms
64 bytes from 10.7.15.60: icmp_seq=2 ttl=64 time=28.082 ms
64 bytes from 10.7.15.60: icmp_seq=3 ttl=64 time=12.153 ms

--- 10.7.15.60 ping statistics ---
4 packets transmitted, 4 packets received, 0.0% packet loss
round-trip min/avg/max/stddev = 12.153/29.676/49.266/13.168 ms
```

**Outcome:** 0.0% packet loss confirms solid bidirectional LAN connectivity between Mac 2 (`10.7.21.116`) and Mac 1 (`10.7.15.60`).

---

### 7. Private vs. Public DNS Resolution & Negative Proofs

Testing isolation of private `.test` domains against public DNS, and demonstrating system resolver failure/recovery modes:

```bash
# 1. Negative Proof: Querying public DNS (8.8.8.8) fails (as expected)
> dig @8.8.8.8 app.teamX.test
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 19754
;; AUTHORITY SECTION:
.    86371   IN   SOA   a.root-servers.net. ...

# 2. Failure Demonstration: Removing custom DNS causes resolution failure
> sudo networksetup -setdnsservers "Wi-Fi" empty
> curl -v https://app.teamX.test:8443
* Could not resolve host: app.teamX.test
* Closing connection
curl: (6) Could not resolve host: app.teamX.test

# 3. Recovery: Pointing to Mac 1 DNS and flushing resolver cache
> sudo networksetup -setdnsservers "Wi-Fi" 10.7.15.60
> sudo dscacheutil -flushcache
> sudo killall -HUP mDNSResponder
> dig app.teamX.test
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52757
;; ANSWER SECTION:
app.teamX.test.   0   IN   A   10.7.21.116
;; SERVER: 10.7.15.60#53(10.7.15.60)
```

**Key Takeaways:**
- Demonstrates why a local DNS server (`dnsmasq`) is necessary for internal `.test` domains.
- Validates macOS system resolver cache management (`dscacheutil`, `mDNSResponder`).

---

### 8. Verbose HTTPS & TLS 1.3 Validation with Trusted Local CA

Full `curl -v` transcript demonstrating seamless TLS 1.3 negotiation with no `-k` bypass:

```text
> curl -v https://app.teamX.test:8443
* Host app.teamX.test:8443 was resolved.
* IPv4: 10.7.21.116
* Trying 10.7.21.116:8443...
* Connected to app.teamX.test (10.7.21.116) port 8443
* ALPN: curl offers h2,http/1.1
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* Server certificate:
*  subject: CN=app.teamX.test
*  start date: Sep 29 13:18:57 2026 GMT
*  expire date: Jan 1 13:18:57 2029 GMT
*  subjectAltName: host "app.teamX.test" matched cert's "app.teamX.test"
*  issuer: CN=TeamX Local Root CA
*  SSL certificate verify ok.
> GET / HTTP/1.1
> Host: app.teamX.test:8443
> User-Agent: curl/8.7.1
> Accept: */*
>
< HTTP/1.1 200 OK
< Server: nginx/1.31.6
< Content-Type: application/json
< Content-Length: 51
< Connection: keep-alive
< X-Backend: A
< Cache-Control: max-age=60
<
{"backend": "A", "message": "Hello from Backend A"}
```

---

### 9. Live Round-Robin Alternation Verification

Direct verification of Nginx round-robin upstream balancing across 6 consecutive requests:

```bash
> for i in {1..6}; do curl -s -D - https://app.teamX.test:8443/api/status -o /dev/null | grep -i "X-Backend"; done
X-Backend: B
X-Backend: A
X-Backend: B
X-Backend: A
X-Backend: B
X-Backend: A
```

**Result:** Perfect 50/50 alternating distribution between Backend B (`10.7.21.116:3002`) and Backend A (`10.7.15.60:3001`).

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
