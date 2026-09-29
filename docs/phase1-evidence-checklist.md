# Phase 1 Evidence Checklist
**Project:** Private Network Service Platform — Phase 1  
**Team:** Nav Prabhat Singh · Shivansh Tiwari

Use this checklist during your demo / lab submission.
Run each command, capture the output, and paste it in the "Evidence / Output" column.

---

## ✅ Checklist

### 1 — DNS: dnsmasq is running on VM1

| Step | Command | Evidence / Output |
|------|---------|-------------------|
| dnsmasq service status | `sudo systemctl status dnsmasq` | _(paste here)_ |
| Listening on UDP/53 | `sudo ss -ulnp \| grep 53` | _(paste here)_ |

---

### 2 — DNS: Name resolution works

Run from a client VM that uses VM1 (`10.7.24.74`) as its nameserver.

| Step | Command | Expected Answer | Evidence / Output |
|------|---------|-----------------|-------------------|
| dig app.teamX.test | `dig app.teamX.test @10.7.24.74` | `192.168.64.6` | _(paste here)_ |
| nslookup app.teamX.test | `nslookup app.teamX.test 10.7.24.74` | `192.168.64.6` | _(paste here)_ |
| dig api.teamX.test | `dig api.teamX.test @10.7.24.74` | `192.168.64.6` | _(paste here)_ |

---

### 3 — Backend A: Running locally on VM2

| Step | Command | Expected | Evidence / Output |
|------|---------|----------|-------------------|
| GET / | `curl -s http://localhost:3001/` | `Hello from Backend A` | _(paste here)_ |
| GET /api/status | `curl -s http://localhost:3001/api/status` | `{"backend":"A","status":"ok"}` | _(paste here)_ |
| X-Backend header | `curl -sI http://localhost:3001/ \| grep X-Backend` | `X-Backend: A` | _(paste here)_ |
| Cache-Control header | `curl -sI http://localhost:3001/ \| grep Cache-Control` | `max-age=60` | _(paste here)_ |
| 404 for unknown path | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3001/bogus` | `404` | _(paste here)_ |

---

### 4 — Backend B: Running locally on VM4

| Step | Command | Expected | Evidence / Output |
|------|---------|----------|-------------------|
| GET / | `curl -s http://localhost:3002/` | `{"backend":"B",...}` | _(paste here)_ |
| GET /api/status | `curl -s http://localhost:3002/api/status` | `{"backend":"B","status":"ok"}` | _(paste here)_ |
| X-Backend header | `curl -sI http://localhost:3002/ \| grep X-Backend` | `X-Backend: B` | _(paste here)_ |
| Cache-Control header | `curl -sI http://localhost:3002/ \| grep Cache-Control` | `max-age=60` | _(paste here)_ |
| Listening on all interfaces | `ss -tlnp \| grep 3002` | `0.0.0.0:3002` | _(paste here)_ |

---

### 5 — Nginx: Config is valid and HTTPS is working

Run on VM3.

| Step | Command | Expected | Evidence / Output |
|------|---------|----------|-------------------|
| Config syntax test | `sudo nginx -t` | `syntax is ok` | _(paste here)_ |
| HTTPS GET / | `curl -k https://192.168.64.6/` | 200 response | _(paste here)_ |
| HTTPS GET /api/status | `curl -k https://192.168.64.6/api/status` | `{"backend":...,"status":"ok"}` | _(paste here)_ |
| X-Backend via Nginx | `curl -k -sI https://192.168.64.6/ \| grep X-Backend` | `X-Backend: A` or `B` | _(paste here)_ |
| Nginx service status | `sudo systemctl status nginx` | `active (running)` | _(paste here)_ |

---

### 6 — Nginx: Upstream / load-balancer config contains both backends

| Step | Command | Expected | Evidence / Output |
|------|---------|----------|-------------------|
| Upstream block present | `grep -A4 'upstream' /etc/nginx/sites-enabled/app.conf` | Both IPs listed | _(paste here)_ |

> **Note:** See *Current Known Limitation* in the main README — direct VM3 → Backend B connectivity
> has been unreliable in the current UTM setup.  Backend B is configured in the upstream
> but end-to-end verification through Nginx is pending network fix.

---

### 7 — HTTPS certificate is present

| Step | Command | Expected | Evidence / Output |
|------|---------|----------|-------------------|
| View cert info | `openssl x509 -in /etc/nginx/ssl/app.crt -noout -subject -dates` | CN=app.teamX.test | _(paste here)_ |
| Verify via curl | `curl -k -v https://192.168.64.6/ 2>&1 \| grep -E 'subject|issuer'` | cert details | _(paste here)_ |

---

### 8 — End-to-end: DNS name → HTTPS → Backend (via VM that uses VM1 as nameserver)

| Step | Command | Expected | Evidence / Output |
|------|---------|----------|-------------------|
| Full chain GET / | `curl -k https://app.teamX.test/` | response from a backend | _(paste here)_ |
| Full chain /api/status | `curl -k https://app.teamX.test/api/status` | `{"backend":...}` | _(paste here)_ |

---

## Summary Status

| Requirement | Status |
|-------------|--------|
| Private DNS (dnsmasq) running on VM1 | ⬜ |
| `.test` namespace (not `.local`) | ⬜ |
| Backend A listening on :3001 | ⬜ |
| Backend B listening on :3002 | ⬜ |
| Nginx as single HTTPS entry point | ⬜ |
| Upstream config includes both backends | ⬜ |
| `GET /` works | ⬜ |
| `GET /api/status` works | ⬜ |
| `X-Backend` header present | ⬜ |
| `Cache-Control: max-age=60` present | ⬜ |
| End-to-end DNS → HTTPS → Backend A | ⬜ |
| End-to-end DNS → HTTPS → Backend B | ⬜ _(pending network fix — see Known Limitation)_ |

> Replace ⬜ with ✅ (verified) or ❌ (not working) during your submission.
