# Evidence Catalog — Private Network Service Platform

This directory contains empirical evidence, logs, and verification outputs demonstrating the correctness of Phase 1 and Phase 2 implementations.

> [!IMPORTANT]
> **Authenticity Policy:** No logs, outputs, or test runs are fabricated. Only actual captured test results are stored. Binary packet capture files (`.pcap`, `.pcapng`) are git-ignored to prevent repository bloat and should be hosted externally or submitted via course portal.

---

## Directory Structure & Evidence Map

```
evidence/
├── README.md                          Overview and evidence catalog
├── dns/
│   ├── .gitkeep
│   └── ttl-proof.txt                  Actual output from Extension B TTL decrement & flush test
├── phase2/
│   ├── .gitkeep
│   └── phase2-mac1-test.txt           Complete live audit output of Mac 1 Phase 2 subsystems
├── caching/
│   └── .gitkeep                       Cache-Control and 304 conditional request traces
├── failures/
│   └── .gitkeep                       Negative proofs, service interruption outputs
├── https/
│   └── .gitkeep                       TLS certificate validation & HTTPS responses
├── load-balancing/
│   └── .gitkeep                       Round-robin alternation logs
└── wireshark/
    └── .gitkeep                       Wireshark trace documentation and frame references
```

---

## Primary Captured Evidence Files

### 1. `evidence/dns/ttl-proof.txt`
- **Subsystem:** Extension B (DNS TTL & Controlled Record Change)
- **Host Captured On:** Mac 1 (`10.7.19.246`)
- **Key Empirical Data:**
  - Initial cached response for `app.team1.test`: `10.7.18.254` with TTL 30.
  - Stale cached response after authoritative record change to `10.7.19.246`: returns `10.7.18.254` with remaining TTL 25.
  - Automatic refresh after 30 seconds: returns `10.7.19.246` with fresh TTL 30.
  - Manual flush test: authoritative reset to `10.7.18.254`; caching resolver returns stale `10.7.19.246` (TTL 26); sending `kill -HUP` flushes memory immediately; next query returns `10.7.18.254` (TTL 30).

### 2. `evidence/phase2/phase2-mac1-test.txt`
- **Subsystem:** Phase 2 Integrated Audit (Extensions A, C, D, E)
- **Host Captured On:** Mac 1 (`10.7.19.246`)
- **Key Empirical Data:**
  - Primary and Backup DNS resolution verification for both `app.team1.test` and `api.team1.test`.
  - Backend A health response: `{"backend":"A","status":"healthy"}`.
  - macOS Packet Filter (PF) anchor `com.apple/cnproject` rule activation.
  - Standby Edge HTTPS response on port 8443 serving Backend A.
  - Active Edge HTTPS response on Mac 2 (`10.7.18.254:8443`) serving Backend B.
  - Direct connection block to Backend B port 3002:
    `curl: (28) Failed to connect to 10.7.18.254 port 3002 after 3004 ms: Timeout was reached`
  - DNS-based edge migration verification.

---

## Wireshark & Packet Capture Files

As specified in `.gitignore`, binary `.pcapng` packet captures are not tracked in the git repository to keep it lightweight.

### Key Captured Packet Sequences
1. **DNS Query & Response:** UDP port 53 query for `app.team1.test` and response containing `10.7.18.254`.
2. **TCP Three-Way Handshake:** Capture on port 8443 showing `SYN` -> `SYN-ACK` -> `ACK` before TLS negotiation.
3. **TLS 1.2 / 1.3 Handshake:** ClientHello (SNI `app.team1.test`), ServerHello, Certificate exchange, and Finished frames.
4. **Encrypted Application Data:** Shows that all HTTP request and response payloads are fully encrypted on the wire.
