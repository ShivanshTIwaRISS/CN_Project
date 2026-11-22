# Phase 2 Implementation Guide — Hardening, Resilience, and Failover

## Overview

Phase 2 builds upon the baseline network infrastructure established in Phase 1 without redesigning or rebuilding the architecture from scratch. The primary objectives are:
1. **Redundancy & High Availability:** Eliminating service disruption during single-node outages.
2. **Network Security & Isolation:** Restricting raw backend access to the reverse proxy edge.
3. **Controlled Operations:** Managing TTL-driven DNS cutover and edge migration.
4. **Diagnostic Methodology:** Isolating failures systematically across the protocol stack.

---

## 1. Extension A: Backup DNS Resolver Architecture

### Architecture & Configuration
In Phase 1, Mac 1 acted as the sole DNS server. If Mac 1 rebooted or its `dnsmasq` service crashed, all hostname resolution ceased immediately.

In Phase 2, DNS resolution is hardened by deploying a second independent `dnsmasq` instance on Mac 2:
- **Primary DNS:** Mac 1 (`10.7.19.246:53`) — configuration: `dns/dnsmasq-primary.conf.example`
- **Backup DNS:** Mac 2 (`10.7.18.254:53`) — configuration: `dns/dnsmasq-backup.conf.example`

Both resolvers serve identical project records:
```conf
address=/app.team1.test/10.7.18.254
address=/api.team1.test/10.7.18.254
local-ttl=30
server=1.1.1.1
server=8.8.8.8
```

### Client Stub Resolver Setup
Client machines configure both nameservers in their network stack:
```bash
sudo networksetup -setdnsservers "Wi-Fi" 10.7.19.246 10.7.18.254
```
macOS sends DNS queries to the primary nameserver. If the primary does not respond within the timeout window, the stub resolver automatically retransmits the query to the backup nameserver.

---

## 2. Extension B: DNS TTL & Controlled Record Change

### Theory & Operation
The Time-To-Live (TTL) field in a DNS Resource Record instructs recursive and client resolvers how long they may cache the record before issuing a new query to authoritative nameservers.
- A high TTL minimizes network query volume but delays traffic redirection during migrations or outages.
- A low TTL enables rapid traffic cutover at the cost of increased DNS traffic.

### Implementation Pattern
To isolate and cleanly measure TTL decay on macOS without interference from the system-wide `mDNSResponder` caching engine, a dedicated caching instance was deployed on Mac 1:
- **Port:** `127.0.0.1:5300`
- **Configuration:** `dns/dnsmasq-client-cache.conf.example`
- **Forwarder:** `server=10.7.19.246#53` (Authoritative Primary DNS)
- **Authoritative TTL:** `local-ttl=30`

### Test Lifecycle
1. **Initial Cache:** Caching resolver queries primary DNS and stores `app.team1.test -> 10.7.18.254` with a 30s TTL.
2. **Authoritative Record Modification:** Primary DNS configuration is updated to point `app.team1.test -> 10.7.19.246`.
3. **Stale Cache Observation:** Immediate query to `127.0.0.1:5300` continues returning `10.7.18.254` with decreasing TTL (e.g. 25 seconds remaining).
4. **Cache Expiry:** Once 30 seconds elapse, the caching resolver forwards a fresh query and immediately returns `10.7.19.246` with fresh TTL 30.
5. **Manual Cache Invalidation:** Authoritative record is changed back to `10.7.18.254`. Querying `127.0.0.1:5300` returns the old answer (`10.7.19.246`, TTL 26). Sending `kill -HUP` to the caching resolver flushes its memory cache, causing the subsequent query to return `10.7.18.254` immediately.

---

## 3. Extension C: Service Isolation via macOS Packet Filter (PF)

### Security Objective
Clients must be restricted from bypassing the Nginx reverse proxy to query internal application servers directly on ports 3001 or 3002. Bypassing the reverse proxy circumvents TLS encryption, logging, rate limiting, and HTTP caching.

### Anchor-Based Isolation Architecture
Rather than modifying the root system firewall `/etc/pf.conf` (which risks system instability or persistent network lockouts), rules are loaded into an isolated project anchor: `com.apple/cnproject`.

#### Mac 1 Policy (`firewall/pf-mac1.conf.example`)
Backend A runs on Mac 1 (port 3001). Traffic to port 3001 must only be permitted from Mac 2 (the Active Nginx edge) or loopback:
```pf
pass in quick on lo0 proto tcp from any to 127.0.0.1 port = 3001 flags S/SA keep state
pass in quick on en0 inet proto tcp from 10.7.18.254 to any port = 3001 flags S/SA keep state
block in quick on en0 inet proto tcp from any to any port = 3001
```

#### Mac 2 Policy (`firewall/pf-mac2.conf.example`)
Backend B runs on Mac 2 (port 3002). Backend B is bound locally and accessible only through loopback (`127.0.0.1:3002`) by Mac 2 Nginx. Direct LAN access to port 3002 is blocked:
```pf
pass in quick on lo0 proto tcp from any to 127.0.0.1 port = 3002 flags S/SA keep state
block in quick on en0 inet proto tcp from any to any port = 3002
```

### Verification & Rollback
- Load and enable:
  ```bash
  sudo pfctl -a com.apple/cnproject -f firewall/pf-mac1.conf.example
  sudo pfctl -e
  ```
- Inspect loaded rules:
  ```bash
  sudo pfctl -a com.apple/cnproject -sr
  ```
- Safe Instant Rollback:
  ```bash
  sudo pfctl -a com.apple/cnproject -F all
  ```

---

## 4. Extension D: High Availability Backend Failover

### Upstream Configuration
Active Nginx on Mac 2 defines the upstream pool in `nginx/phase2-active.conf.example`:
```nginx
upstream backend_pool {
    server 10.7.19.246:3001 max_fails=1 fail_timeout=10s;
    server 127.0.0.1:3002 max_fails=1 fail_timeout=10s;
}
```

### Proxy Failover Directives
```nginx
location / {
    proxy_pass http://backend_pool;
    proxy_http_version 1.1;

    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    proxy_connect_timeout 2s;
    proxy_read_timeout 10s;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
}
```

### Fault Injection & Healing Mechanics
1. **Fault Injection:** Process for Backend A on Mac 1 is killed (`kill <pid>`).
2. **Client Request:** When Nginx attempts to forward a request to `10.7.19.246:3001`, the connection fails (`Connection Refused`).
3. **Transparent Failover:** `proxy_next_upstream` immediately reroutes the exact request to `127.0.0.1:3002` (Backend B). The client receives a seamless `200 OK` with header `X-Backend: B`.
4. **Passive Circuit Breaking:** Nginx marks Backend A as down for the duration of `fail_timeout=10s`. Subsequent client requests are sent directly to Backend B.
5. **Auto-Recovery:** Backend A is restarted. Once the 10-second timer elapses, Nginx attempts a probe connection. Upon success, Backend A is returned to active round-robin rotation.

---

## 5. Extension E: Controlled Edge Migration

### Architectural Problem: Edge Single Point of Failure (SPOF)
In the normal operational baseline, Nginx on Mac 2 is a Single Point of Failure. If Mac 2 suffers a hardware failure, kernel panic, or power outage, the HTTPS edge ceases functioning even if Backend A on Mac 1 is healthy.

### Migration Solution: Warm Standby Edge
1. **Standby Proxy Provisioning:** Mac 1 runs a standby Nginx instance on port 8443 (`nginx/phase2-standby.conf.example`) with identical TLS certificates and domain configurations.
2. **Local Upstream Routing:** The standby proxy connects directly to local Backend A (`127.0.0.1:3001`).
3. **Controlled DNS Cutover:**
   - Authoritative DNS records are updated: `app.team1.test` → `10.7.19.246` (Mac 1).
   - `api.team1.test` remains pointing to `10.7.18.254` (Mac 2).
4. **Verification:** Clients querying `https://app.team1.test:8443/` route to Mac 1 and receive responses from Backend A.

---

## 6. Extension F: Troubleshooting Challenge Framework

Extension F prepares the team to diagnose arbitrary faculty-injected configuration faults live during final evaluation. The complete diagnostic runbook and layer-by-layer methodology is provided in `docs/troubleshooting.md`.
