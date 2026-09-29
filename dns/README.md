# DNS — README

## What this directory contains

| File | Purpose |
|------|---------|
| `dnsmasq.conf.example` | Example dnsmasq configuration for VM1 |

---

## Role of VM1 in the project

VM1 runs **dnsmasq** and acts as the private DNS resolver for the `.test`
domain.  All client machines (or VMs) in the lab network point their
`/etc/resolv.conf` (or equivalent) at VM1's IP so that names like
`app.teamX.test` resolve correctly.

```
Client
  │  (DNS query: app.teamX.test?)
  ▼
VM1  10.7.24.74   ← dnsmasq answers: 192.168.64.6
```

DNS resolves to **VM3 (Nginx)**, not directly to the backend VMs.

---

## Why `.test` and not `.local`

`.local` is reserved by **mDNS / Avahi** (RFC 6762) and causes hard-to-debug
conflicts on Linux and macOS.  We use the IANA-reserved `.test` TLD (RFC 2606)
which is safe for private/lab networks and is never registered on the public
internet.

---

## Deploying on VM1

```bash
# 1. Install dnsmasq (if not already installed)
sudo apt install dnsmasq

# 2. Copy the example config
sudo cp dns/dnsmasq.conf.example /etc/dnsmasq.d/teamX.conf

# 3. Restart dnsmasq
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# 4. Verify it is listening
sudo ss -ulnp | grep 53
```

## Pointing a client at VM1

Edit `/etc/resolv.conf` on the client VM (or configure systemd-resolved):

```
nameserver 10.7.24.74
```

---

## Testing DNS resolution

```bash
# From any VM that uses VM1 as its nameserver
dig app.teamX.test @10.7.24.74
nslookup app.teamX.test 10.7.24.74

# Expected answer: 192.168.64.6 (VM3 / Nginx)
```
