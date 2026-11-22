# Phase 2 Final Demonstration Runbook

This runbook defines the exact 11-step evaluation sequence specified in Section 8 of the Computer Networks course project specification. Every step includes the exact terminal command to execute, the expected output, and the protocol explanation.

---

## Pre-Demo Checklist

Before starting the evaluation with the faculty evaluator:
- [ ] Both Mac 1 (`10.7.19.246`) and Mac 2 (`10.7.18.254`) connected to the shared Wi-Fi LAN.
- [ ] System DNS on both Macs set to `10.7.19.246 10.7.18.254`.
- [ ] Root CA trusted in macOS Keychain on both machines.
- [ ] DNS in **Normal State** (Both `app.team1.test` and `api.team1.test` point to `10.7.18.254`).
- [ ] Both Backend A (port 3001) and Backend B (port 3002) running.
- [ ] Active Nginx running on Mac 2 (port 8443).

---

## Step-by-Step 11-Step Demonstration Sequence

### Step 1: Show Topology and IP/Service Inventory
**What Evaluator Expects:** Network diagram, IP table, and service map showing both Macs and four logical roles.
- **Action:** Open `docs/architecture.md` and display the machine and service inventory table.
- **Explanation:** Explain that our team has 2 physical MacBooks and 2 members (Shivansh Tiwari and Nav Prabhat Singh), combining the 4 logical roles (Primary/Backup DNS, Active/Standby Edge, Backend A/B).

---

### Step 2: Confirm LAN Reachability Between All Machines
**What Evaluator Expects:** Bidirectional ping showing 0.0% packet loss and private IP addresses.
- **Command (from Mac 1):**
  ```bash
  ping -c 4 10.7.18.254
  ```
- **Command (from Mac 2):**
  ```bash
  ping -c 4 10.7.19.246
  ```
- **Expected Output:** 4 packets transmitted, 4 packets received, 0.0% packet loss.

---

### Step 3: Resolve Private Domain from a Client
**What Evaluator Expects:** Name resolution using the team's DNS server resolving to Mac 2.
- **Command:**
  ```bash
  dig app.team1.test
  ```
- **Expected Output:**
  `ANSWER SECTION: app.team1.test. 30 IN A 10.7.18.254`
  `SERVER: 10.7.19.246#53` (or `10.7.18.254#53`)
- **Explanation:** Explain the separation between DNS resolution (Layer 7 UDP 53 directory lookup) and the subsequent TCP/TLS connection.

---

### Step 4: Open Service Over HTTPS Using the Domain Name
**What Evaluator Expects:** Access `https://app.team1.test:8443` without certificate errors and without `-k`.
- **Command:**
  ```bash
  curl -v https://app.team1.test:8443/api/status
  ```
- **Expected Output:**
  `* SSL certificate verify ok.`
  `HTTP/1.1 200 OK`
  `{"backend":"...","status":"ok"}`
- **Explanation:** Explain the TLS handshake (ClientHello -> ServerHello -> Certificate -> Key Exchange -> Finished) and how trusting our local Root CA in Keychain enables verification without `-k`.

---

### Step 5: Show Load Balancing Across Both Backends
**What Evaluator Expects:** Repeated requests alternating between Backend A and Backend B.
- **Command:**
  ```bash
  ./scripts/test-load-balancing.sh
  ```
- **Expected Output:**
  ```text
  Request  1: X-Backend: B
  Request  2: X-Backend: A
  Request  3: X-Backend: B
  Request  4: X-Backend: A
  ...
  ```
- **Explanation:** Explain Nginx upstream round-robin scheduling and how the client is completely unaware of the private backend IPs.

---

### Step 6: Show Wireshark Packet Analysis
**What Evaluator Expects:** Visual inspection of DNS query/response, TCP three-way handshake, and TLS handshake frames.
- **Action:** Open Wireshark and show captured frames:
  - DNS query/response (filter: `udp.port == 53`).
  - TCP Three-Way Handshake (filter: `tcp.port == 8443`, show SYN, SYN-ACK, ACK with seq/ack numbers).
  - TLS Handshake (ClientHello, ServerHello, Certificate, Finished).
  - Encrypted Application Data frames.

---

### Step 7: Show HTTP Headers and Caching Behavior
**What Evaluator Expects:** `Cache-Control` headers and conditional `304 Not Modified` or cache hit demonstration.
- **Command 1 (Initial Request):**
  ```bash
  curl -i https://app.team1.test:8443/api/info
  ```
  *Show headers: `Cache-Control: public, max-age=30`, `ETag: "cn-project-v1"`.*
- **Command 2 (Conditional Request):**
  ```bash
  curl -i -H 'If-None-Match: "cn-project-v1"' https://app.team1.test:8443/api/info
  ```
- **Expected Output:**
  `HTTP/1.1 304 Not Modified` with no response body.
- **Explanation:** Explain the difference between fresh cache hit, conditional revalidation (304), and full transfer (200).

---

### Step 8: Fail One Backend and Prove High-Availability Failover (Extension D)
**What Evaluator Expects:** Service continues without client errors when Backend A stops.
- **Action 1 (Kill Backend A on Mac 1):**
  ```bash
  # Identify and kill Backend A process
  kill $(lsof -ti :3001)
  ```
- **Action 2 (Run 6 Requests):**
  ```bash
  for i in {1..6}; do curl -s -D - https://app.team1.test:8443/api/status -o /dev/null | grep -i "X-Backend"; done
  ```
  *Expected: All 6 return `X-Backend: B`.*
- **Action 3 (Restart Backend A):**
  ```bash
  ./scripts/run-backend-a-node.sh &
  ```
- **Action 4 (Observe Auto-Recovery):**
  ```bash
  for i in {1..8}; do curl -s -D - https://app.team1.test:8443/api/status -o /dev/null | grep -i "X-Backend"; done
  ```
  *Expected: Distribution returns to alternating between A and B.*

---

### Step 9: Demonstrate Phase 2 DNS Resilience & Cutover (Extensions A/B/E)
**What Evaluator Expects:** Backup DNS failover, TTL decrement/expiry, or DNS-based edge cutover.

#### Option A: Backup DNS Failover (Extension A)
1. Stop Primary DNS on Mac 1: `sudo brew services stop dnsmasq`
2. Run client query: `dig app.team1.test` -> Resolves via Backup DNS (`10.7.18.254`).
3. Restart Primary DNS: `sudo brew services start dnsmasq`

#### Option B: TTL Caching Demonstration (Extension B)
Run the automated script reproducing the TTL test:
```bash
./scripts/demo-dns-ttl.sh
```
Show the recorded proof in `evidence/dns/ttl-proof.txt`.

#### Option C: Controlled Edge Migration (Extension E)
1. Show Standby Nginx on Mac 1 (`https://10.7.19.246:8443`).
2. Switch DNS record: `address=/app.team1.test/10.7.19.246`.
3. Client query routes to Mac 1 and returns Backend A.

---

### Step 10: Diagnose Faculty-Injected Fault (Extension F)
**What Evaluator Expects:** Team uses systematic layered diagnostic methodology to locate and isolate an injected fault.
- Follow the exact sequence in `docs/troubleshooting.md`:
  1. Check DNS (`dig app.team1.test`).
  2. Check TCP Socket (`nc -zv <ip> <port>`).
  3. Check TLS Handshake (`openssl s_client -connect <ip>:8443`).
  4. Check Application / Upstream (`curl http://localhost:<port>/health`).
- Vocalize hypothesis, test observation, and conclusion at each step.

---

### Step 11: Individual Viva Questions
**What Evaluator Expects:** Each student answers individually based on foundational understanding.
- Shivansh Tiwari (Mac 1 Lead): Primary DNS, dnsmasq internals, TTL caching, Backend A, Standby Nginx, PF isolation on Mac 1.
- Nav Prabhat Singh (Mac 2 Lead): Backup DNS, Active Nginx reverse proxy, HA upstream failover (`proxy_next_upstream`), Backend B, PF isolation on Mac 2.
