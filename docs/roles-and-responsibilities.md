# Team Roles & System Responsibilities

## Team Composition & Allocation

The project is executed by a two-student engineering team utilizing two physical Apple MacBook computers to fulfill four logical networking roles.

| Student Name | Assigned Machine | IP Address (`en0`) | Primary Logical Roles |
|--------------|------------------|--------------------|-----------------------|
| **Shivansh Tiwari** | **Mac 1** | `10.7.19.246` | Primary DNS Server (`dnsmasq`)<br>Standby HTTPS Reverse Proxy (`nginx`)<br>Backend A Application Server<br>Client Test & Diagnostic Node |
| **Nav Prabhat Singh** | **Mac 2** | `10.7.18.254` | Backup DNS Server (`dnsmasq`)<br>Active HTTPS Edge & Load Balancer (`nginx`)<br>Backend B Application Server<br>Client Test & Diagnostic Node |

---

## Machine 1 Deep Dive — Shivansh Tiwari

### Hardware & Network Configuration
- **Hostname:** `Shivanshs-MacBook-Pro-4.local`
- **Interface:** `en0` (Wi-Fi)
- **IPv4 Address:** `10.7.19.246`

### Subsystems Owned & Operated
1. **Primary DNS Server (`dnsmasq`):**
   - Port: `53` (UDP/TCP)
   - Configuration: `dns/dnsmasq-primary.conf.example`
   - Configured with `local-ttl=30`, authoritative mapping for `team1.test` domain.
   - Upstream forwarders: `1.1.1.1`, `8.8.8.8`.
2. **Backend Application Server A:**
   - Port: `3001` (TCP)
   - Runtime: Node.js (`node-backend/server.js`) & Python (`backend-a/server.py`)
   - Emits header: `X-Backend: A`
   - Endpoints: `/`, `/api/status`, `/health`, `/api/info`
3. **Standby HTTPS Reverse Proxy (`nginx`):**
   - Port: `8443` (TCP / TLS)
   - Configuration: `nginx/phase2-standby.conf.example`
   - Warm standby edge for Extension E (Controlled Edge Migration).
   - Proxies traffic to local Backend A (`127.0.0.1:3001`).
4. **Packet Filter Security Anchor (`pfctl`):**
   - Configuration: `firewall/pf-mac1.conf.example`
   - Allows port 3001 access strictly from Mac 2 (`10.7.18.254`) and loopback; drops unauthorized external LAN traffic.
5. **DNS TTL Caching Resolver:**
   - Port: `5300` (TCP/UDP)
   - Configuration: `dns/dnsmasq-client-cache.conf.example`
   - Used for the Extension B empirical caching and TTL decrement proof.

### Viva Focus Areas (Shivansh Tiwari)
- DNS protocol internals, authoritative vs recursive resolvers, TTL caching and decrement.
- macOS resolver behavior (`mDNSResponder`, `scutil --dns`).
- Standby edge migration patterns and DNS cutover latency.
- Packet Filter (PF) syntax, stateful filtering (`keep state`), and project anchor isolation.

---

## Machine 2 Deep Dive — Nav Prabhat Singh

### Hardware & Network Configuration
- **Hostname:** `Navprabhats-MacBook-Air.local`
- **Interface:** `en0` (Wi-Fi)
- **IPv4 Address:** `10.7.18.254`

### Subsystems Owned & Operated
1. **Backup DNS Server (`dnsmasq`):**
   - Port: `53` (UDP/TCP)
   - Configuration: `dns/dnsmasq-backup.conf.example`
   - Maintains synchronized duplicate zone records for `team1.test`.
   - Answers client queries when Primary DNS is down (Extension A).
2. **Active HTTPS Edge Reverse Proxy & Load Balancer (`nginx`):**
   - Port: `8443` (TCP / TLS)
   - Configuration: `nginx/phase2-active.conf.example`
   - Terminates TLS 1.2 / TLS 1.3 with locally trusted certificate.
   - Distributes client traffic across Backend A (`10.7.19.246:3001`) and Backend B (`127.0.0.1:3002`).
   - High-Availability Passive Health Checks: `max_fails=1 fail_timeout=10s`, `proxy_next_upstream`.
3. **Backend Application Server B:**
   - Port: `3002` (TCP)
   - Runtime: Node.js (`node-backend/server.js`) & Python (`backend-b/server.py`)
   - Emits header: `X-Backend: B`
   - Endpoints: `/`, `/api/status`, `/health`, `/api/info`
4. **Packet Filter Security Anchor (`pfctl`):**
   - Configuration: `firewall/pf-mac2.conf.example`
   - Blocks external LAN access to port 3002, restricting Backend B strictly to loopback access by local Nginx.

### Viva Focus Areas (Nav Prabhat Singh)
- TLS termination, certificate hierarchy, X.509 extensions (SAN), and Keychain trust stores.
- Nginx reverse proxy architecture, upstream load-balancing algorithms, and passive health checking.
- High-availability failover mechanisms (`proxy_next_upstream`) and edge single-point-of-failure mitigation.
- HTTP caching headers (`Cache-Control`, `max-age`), ETags, and conditional `304 Not Modified` revalidation.
