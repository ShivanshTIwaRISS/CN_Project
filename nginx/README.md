# Nginx — README

## What this directory contains

| File | Purpose |
|------|---------|
| `app.conf` | Nginx virtual-host config: HTTPS listener + upstream load-balancer |

---

## Deploying on VM3

1. **Copy** (or symlink) `app.conf` to the Nginx sites directory:

   ```bash
   sudo cp app.conf /etc/nginx/sites-available/app.conf
   sudo ln -s /etc/nginx/sites-available/app.conf \
              /etc/nginx/sites-enabled/app.conf
   ```

2. **Create the SSL directory and place your certificate files:**

   ```bash
   sudo mkdir -p /etc/nginx/ssl
   sudo cp app.crt /etc/nginx/ssl/app.crt   # certificate (public, OK to share)
   sudo cp app.key /etc/nginx/ssl/app.key   # private key  (NEVER commit this)
   sudo chmod 600 /etc/nginx/ssl/app.key
   ```

   > **Note:** The `.key` file is listed in `.gitignore` and must never be
   > pushed to the repository.  The paths in `app.conf` reference the VM3
   > local filesystem only.

3. **Test and reload:**

   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

---

## Updating backend IPs

If VM2 or VM4 receive new DHCP addresses, edit the `upstream` block in
`app.conf`:

```nginx
upstream backends {
    server <NEW_VM2_IP>:3001;   # Backend A
    server <NEW_VM4_IP>:3002;   # Backend B
}
```

Then re-run `nginx -t && systemctl reload nginx`.

---

## Generating a self-signed certificate (lab use only)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout app.key \
  -out app.crt \
  -subj "/CN=app.teamX.test"
```

Copy the resulting files to `/etc/nginx/ssl/` on VM3 as shown above.

---

## Quick-check commands

```bash
# Verify config syntax
sudo nginx -t

# Check HTTPS is up (ignore self-signed cert warning with -k)
curl -k https://192.168.64.6/
curl -k https://192.168.64.6/api/status
curl -k -v https://192.168.64.6/ 2>&1 | grep X-Backend

# Check which backend served the request
curl -k -s -o /dev/null -w "HTTP %{http_code}\n" https://192.168.64.6/api/status
```
