# Multi-Layer Troubleshooting & Diagnostic Guide

## Overview & Diagnostic Philosophy

In enterprise networking and during the Phase 2 live evaluation (Extension F), random guessing wastes time. When a fault is injected or a service fails, apply **layered diagnostic isolation** from the bottom up (or systematically across the request flow):

```
+─────────────────────────────────────────────────────────────────────────+
| Layer 1: DNS Layer            Does the name resolve to the correct IP?  |
+─────────────────────────────────────────────────────────────────────────+
                                    │ YES
+─────────────────────────────────────────────────────────────────────────+
| Layer 2: TCP Layer            Is the target port open and reachable?    |
+─────────────────────────────────────────────────────────────────────────+
                                    │ YES
+─────────────────────────────────────────────────────────────────────────+
| Layer 3: TLS Layer            Can a secure session be negotiated?       |
+─────────────────────────────────────────────────────────────────────────+
                                    │ YES
+─────────────────────────────────────────────────────────────────────────+
| Layer 4: Application Layer    Does the HTTP server / backend respond?   |
+─────────────────────────────────────────────────────────────────────────+
```

---

## 1. Diagnostic Matrix: Symptom to Layer Identification

| Error Symptom Observed by Client | Most Probable Layer | Root Cause Candidates |
|----------------------------------|---------------------|-----------------------|
| `curl: (6) Could not resolve host` | **DNS Layer** | DNS server down, wrong nameserver in `/etc/resolv.conf`, syntax error in `dnsmasq.conf`, domain typo |
| `;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN` | **DNS Layer** | DNS server is reachable, but the record is missing or mistyped in dnsmasq |
| `curl: (7) Failed to connect to ...: Connection refused` | **TCP Layer** | Target IP is reachable, but service daemon is not running or listening on that port |
| `curl: (28) Failed to connect to ...: Timeout was reached` | **TCP / Network Layer** | Physical network disconnected, host powered down, wrong IP, or **firewall (PF) dropping packets** |
| `curl: (60) SSL certificate problem: unable to get local issuer certificate` | **TLS Layer** | Local Root CA is not installed or not marked trusted in macOS Keychain |
| `curl: (35) error:0A000438:SSL routines::tlsv1 alert internal error` | **TLS Layer** | TLS protocol mismatch, invalid cipher, corrupted certificate/key file, or SNI mismatch |
| `HTTP/1.1 502 Bad Gateway` | **Application / Upstream Layer** | Nginx is healthy and TLS terminated, but **both backends are dead** or unreachable by Nginx |
| `HTTP/1.1 404 Not Found` | **Application Layer** | Edge proxy and backends are running, but requested URL path does not exist |
| `HTTP/1.1 405 Method Not Allowed`| **Application Layer** | Method (e.g. POST) not supported by the backend handler |

---

## 2. Layer-by-Layer Diagnostic Procedures

### Layer 1: DNS Diagnostics

#### Step 1.1: Verify DNS Resolver Reachability & Query
```bash
# Query Primary DNS explicitly
dig @10.7.19.246 app.team1.test

# Query Backup DNS explicitly
dig @10.7.18.254 app.team1.test

# Query via system configured resolver (no @)
dig app.team1.test
```
- **Expected:** `status: NOERROR`, Answer Section contains `10.7.18.254` (or `10.7.19.246`).
- **If Timeout:** Check whether `dnsmasq` is running on the target machine:
  ```bash
  sudo lsof -nP -i :53
  ```
- **If NXDOMAIN:** Check zone configuration in `/opt/homebrew/etc/dnsmasq.conf`:
  ```bash
  grep "app.team1.test" /opt/homebrew/etc/dnsmasq.conf
  ```

#### Step 1.2: Check Client Resolver Configuration
```bash
# View configured system DNS servers
scutil --dns | grep "nameserver\["

# View Network Setup DNS
networksetup -getdnsservers "Wi-Fi"
```
To reconfigure:
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.19.246 10.7.18.254
```

#### Step 1.3: Flush macOS DNS Cache
```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

---

### Layer 2: TCP Transport Diagnostics

#### Step 2.1: Test TCP Port Connectivity using `nc` (Netcat)
```bash
# Test Active Nginx on Mac 2
nc -zv 10.7.18.254 8443

# Test Backend A on Mac 1
nc -zv 10.7.19.246 3001

# Test Backend B on Mac 2
nc -zv 10.7.18.254 3002
```
- **Output: `Connection to 10.7.18.254 port 8443 [tcp] succeeded!`** → TCP handshake succeeded; layer 4 is operational.
- **Output: `Connection refused`** → Host is up, but no application is listening on that port. Check `lsof -i :<port>` on the server.
- **Output: `Operation timed out`** → Packets are not reaching or are being silently dropped. Check Wi-Fi connectivity (`ping`) or Packet Filter rules (`sudo pfctl -sr`).

#### Step 2.2: Verify Server Listening Sockets (`lsof`)
Run on the local server machine:
```bash
# Check all relevant ports
lsof -nP -i :53 -i :8443 -i :3001 -i :3002
```
Verify that processes are bound to `0.0.0.0` or the appropriate interface IP, not just `127.0.0.1` (unless intended for local loopback like Backend B).

---

### Layer 3: TLS Presentation Diagnostics

#### Step 3.1: Inspect TLS Handshake with OpenSSL
```bash
openssl s_client -connect 10.7.18.254:8443 -servername app.team1.test -showcerts </dev/null
```
- **Look for:** `Verify return code: 0 (ok)`.
- **Subject Alternative Names (SAN):** Verify that `DNS:app.team1.test` and `DNS:api.team1.test` are listed.
- **Handshake Protocol:** Confirm `Protocol: TLSv1.2` or `Protocol: TLSv1.3`.

#### Step 3.2: Verify Local Root CA Trust in Keychain
If `curl` reports certificate verification errors without `-k`:
```bash
# Re-import and trust the local CA on macOS
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain certs/rootCA.pem
```

---

### Layer 4: Application & Reverse Proxy Diagnostics

#### Step 4.1: Query Direct Backend Application
Bypass Nginx to isolate whether the failure is inside the backend app or inside the proxy:
```bash
# Query Backend A
curl -v http://10.7.19.246:3001/health

# Query Backend B (from Mac 2)
curl -v http://127.0.0.1:3002/health
```

#### Step 4.2: Inspect Nginx Error Logs
If Nginx returns `502 Bad Gateway`:
```bash
tail -n 20 /tmp/cn-nginx-active-error.log
# Look for:
# "connect() failed (61: Connection refused) while connecting to upstream"
# "upstream timed out (60: Operation timed out) while connecting to upstream"
```

#### Step 4.3: Verify Caching & ETag Behavior
```bash
# First request: should return 200 OK + ETag
curl -i https://app.team1.test:8443/api/info

# Conditional request: should return 304 Not Modified
curl -i -H 'If-None-Match: "cn-project-v1"' https://app.team1.test:8443/api/info
```

---

## 3. Rapid Faculty Fault Diagnostic Walkthrough

When an injected fault occurs during evaluation:
1. **Run:** `dig app.team1.test`
   - If fails → Problem is **DNS**. Check dnsmasq process, network DNS settings, or zone files.
2. **Run:** `nc -zv <resolved_ip> 8443`
   - If fails → Problem is **TCP / Nginx Edge**. Check if Nginx is running or if PF is blocking.
3. **Run:** `openssl s_client -connect <resolved_ip>:8443 -servername app.team1.test`
   - If fails → Problem is **TLS**. Check certificates, private key permissions, or trust store.
4. **Run:** `curl -v https://app.team1.test:8443/api/status`
   - If returns `502 Bad Gateway` → Problem is **Upstream Backends**. Check backend processes on ports 3001/3002.
   - If returns `200 OK` → Entire pipeline is operating normally.
