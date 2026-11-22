# Phase 2 Test Results & Empirical Evidence

This document records the empirical results, terminal transcripts, and verification outputs obtained from testing Phase 2 across the two physical MacBooks (`Mac 1: 10.7.19.246` and `Mac 2: 10.7.18.254`).

---

## 1. Extension A: Backup DNS Resolver Results

### Primary DNS Service Outage & Failover Test
1. **Initial State:**
   - Primary DNS (`10.7.19.246:53`) running on Mac 1.
   - Backup DNS (`10.7.18.254:53`) running on Mac 2.
   - Client DNS configured: `10.7.19.246`, `10.7.18.254`.

2. **Fault Injection:**
   Primary DNS daemon stopped on Mac 1:
   ```bash
   sudo brew services stop dnsmasq
   ```

3. **Client Resolution During Primary Outage:**
   ```bash
   $ dig app.team1.test +noall +answer +comments
   ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 41928
   ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

   ;; ANSWER SECTION:
   app.team1.test.     30  IN  A   10.7.18.254

   ;; SERVER: 10.7.18.254#53(10.7.18.254)
   ;; WHEN: Sun Nov 22 22:10:14 IST 2026
   ```

   ```bash
   $ dig api.team1.test +noall +answer +comments
   ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 41929
   ;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

   ;; ANSWER SECTION:
   api.team1.test.     30  IN  A   10.7.18.254

   ;; SERVER: 10.7.18.254#53(10.7.18.254)
   ```

4. **Result Analysis:**
   The client stub resolver detected that `10.7.19.246` was unreachable and seamlessly failed over to query the backup resolver at `10.7.18.254`. The query succeeded with `status: NOERROR` and identified `SERVER: 10.7.18.254#53`.
5. **Recovery:**
   Primary DNS was restarted (`sudo brew services start dnsmasq`). Queries to both resolvers were verified functional.
6. **Status:** **PASSED**

---

## 2. Extension B: DNS TTL and Controlled Record Change Results

Captured live on Mac 1 and saved in `evidence/dns/ttl-proof.txt`.

### Empirical Execution Transcript
```text
========== TTL DEMONSTRATION ==========
dnsmasq: syntax check OK.
dnsmasq: syntax check OK.
========== 1. CACHE OLD IP ==========

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 5300 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     30  IN  A   10.7.18.254
========== 2. CHANGE AUTHORITATIVE DNS ==========
dnsmasq: syntax check OK.
NEW AUTHORITATIVE ANSWER:

; <<>> DiG 9.10.6 <<>> @10.7.19.246 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     30  IN  A   10.7.19.246
OLD CACHED ANSWER:

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 5300 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     25  IN  A   10.7.18.254
========== 3. WAIT FOR TTL EXPIRY ==========
CACHED ANSWER AFTER TTL EXPIRY:

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 5300 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     30  IN  A   10.7.19.246
========== 4. MANUAL CACHE FLUSH ==========
dnsmasq: syntax check OK.
NEW AUTHORITATIVE ANSWER:

; <<>> DiG 9.10.6 <<>> @10.7.19.246 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     30  IN  A   10.7.18.254
BEFORE MANUAL FLUSH:

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 5300 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     26  IN  A   10.7.19.246
AFTER MANUAL FLUSH:

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 5300 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     30  IN  A   10.7.18.254
========== 5. FINAL DNS STATE ==========
Restoring application to Mac 1...
dnsmasq: syntax check OK.

; <<>> DiG 9.10.6 <<>> @10.7.19.246 app.team1.test +noall +answer
; (1 server found)
;; global options: +cmd
app.team1.test.     30  IN  A   10.7.19.246
========== TTL PROOF FINISHED ==========
```

### Key Quantitative Observations
1. **Initial Cache:** `10.7.18.254` stored with TTL 30.
2. **Decreasing TTL on Stale Record:** After authoritative update to `10.7.19.246`, the caching resolver returned the stale record with remaining TTL 25.
3. **Automatic Refresh after Expiry:** Once 30 seconds elapsed, cache returned `10.7.19.246` with fresh TTL 30.
4. **Instant Invalidation via SIGHUP:** Authoritative record reset to `10.7.18.254`. Caching resolver had 26s remaining on old answer; upon receiving `kill -HUP`, the stale record was purged immediately, returning `10.7.18.254` with TTL 30 on the very next query.
5. **Status:** **PASSED**

---

## 3. Extension C: Service Isolation / Backend Firewall Results

Captured live and archived in `evidence/phase2/phase2-mac1-test.txt`.

### macOS Packet Filter Application
```text
========== APPLY MAC 1 BACKEND FIREWALL ==========
pass in quick on en0 inet proto tcp from 10.7.18.254 to any port = 3001 flags S/SA keep state
block drop in quick on en0 inet proto tcp from any to any port = 3001
```

### Isolation Verification
1. **Local Access (Mac 2 -> Backend B):**
   ```bash
   $ curl http://127.0.0.1:3002/health
   {"backend":"B","status":"healthy"}
   ```
2. **Reverse Proxy Access (Mac 2 Nginx -> Backends):**
   ```bash
   $ curl https://app.team1.test:8443/api/status
   {"backend":"A","status":"ok","hostname":"Shivanshs-MacBook-Pro-4.local","port":3001}
   $ curl https://app.team1.test:8443/api/status
   {"backend":"B","status":"ok","hostname":"Navprabhats-MacBook-Air.local","port":3002}
   ```
   Nginx successfully reached both local Backend B and remote Backend A through the PF pinhole.
3. **Direct Unauthorized Access Blocked (Mac 1 -> Backend B Port 3002):**
   ```text
   ========== DIRECT BACKEND B ACCESS TEST ==========
   PASS: Direct Backend B connection was blocked or unavailable.
   curl: (28) Failed to connect to 10.7.18.254 port 3002 after 3004 ms: Timeout was reached
   ```
   **Observation:** Direct TCP connection was silently dropped by PF on Mac 2, causing a client timeout after 3004 ms.
4. **Topology Limitation Disclosure:**
   In our two-laptop topology, Mac 1 hosts both Backend A and client tools, and Mac 2 hosts both Backend B and Active Nginx. Because there is no 3rd physical client machine on the LAN, testing unauthorized access to Backend A (port 3001) from an external non-edge client could not be physically executed.
5. **Status:** **PASSED WITH TWO-MAC TOPOLOGY LIMITATION**

---

## 4. Extension D: High Availability Failover Results

### Test Execution
1. **Upstream Pool Baseline:**
   Requests distributed 50/50 between Backend A (`10.7.19.246:3001`) and Backend B (`127.0.0.1:3002`).
2. **Backend A Failure Injection:**
   Backend A process on Mac 1 was killed via SSH using its process ID.
3. **Continuous Request Audit Through Active Nginx:**
   Six consecutive requests were sent to `https://app.team1.test:8443/api/status`:
   ```bash
   for i in {1..6}; do
     curl -s -D - https://app.team1.test:8443/api/status -o /dev/null | grep -i "X-Backend"
   done
   ```
   **Output:**
   ```text
   X-Backend: B
   X-Backend: B
   X-Backend: B
   X-Backend: B
   X-Backend: B
   X-Backend: B
   ```
   Zero dropped requests, zero HTTP 502 Bad Gateway responses received by the client.
4. **Backend A Recovery:**
   Backend A restarted. Health verified:
   ```bash
   $ curl http://10.7.19.246:3001/health
   {"backend":"A","status":"healthy"}
   ```
5. **Observed Post-Recovery Sequence:**
   Subsequent repeated requests demonstrated the re-admission and round-robin re-balancing:
   ```text
   B, B, A, B, A, B, A, B
   ```
   - First 2 requests went to Backend B while Nginx observed Backend A's recovery.
   - Alternating distribution between Backend A and Backend B resumed automatically.
6. **Status:** **PASSED**

---

## 5. Extension E: Controlled Edge Migration Results

### Test Execution
1. **Standby Edge Verification on Mac 1:**
   ```bash
   $ curl -s https://127.0.0.1:8443/api/status -H "Host: app.team1.test"
   {"backend":"A","status":"ok","hostname":"Shivanshs-MacBook-Pro-4.local","port":3001}
   ```
2. **Active Edge Verification on Mac 2:**
   ```bash
   $ curl -s https://10.7.18.254:8443/api/status -H "Host: app.team1.test"
   {"backend":"B","status":"ok","hostname":"Navprabhats-MacBook-Air.local","port":3002}
   ```
3. **DNS Cutover Execution:**
   Authoritative records on both Primary and Backup DNS updated:
   - `address=/app.team1.test/10.7.19.246`
   - `address=/api.team1.test/10.7.18.254`
4. **Post-Migration Verification:**
   Standard HTTPS request to `https://app.team1.test:8443` reached Mac 1 (`10.7.19.246`) and served Backend A.
5. **Pending Capture Note:**
   While the cutover and standby edge were successfully validated, capturing the simultaneous side-by-side behavior of a stale-cache client reaching Mac 2 while a fresh client reaches Mac 1 is documented as pending separate capture (Extension B validated TTL caching separately).
6. **Status:** **IMPLEMENTED AND MIGRATION VERIFIED; OLD-CACHE/NEW-EDGE OVERLAP EVIDENCE PENDING**

---

## 6. Extension F: Faculty Troubleshooting

- Status: **PENDING LIVE FACULTY EVALUATION**
- Reference: `docs/troubleshooting.md`
