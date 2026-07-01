# Custom Domain Setup — `waerweiss.ch`

Task list to put the quiz app behind `waerweiss.ch`, serving the app from
**Fly.io** and images from **Cloudflare R2**. Domain registered at **Infomaniak**,
DNS managed by **Cloudflare**.

## Target layout

| Hostname | Points to | Cloudflare proxy | Purpose |
|---|---|---|---|
| `waerweiss.ch` (apex) | Fly.io | **DNS-only** (grey) | app |
| `www.waerweiss.ch` | Fly.io | **DNS-only** (grey) | app |
| `images.waerweiss.ch` | Cloudflare R2 | **Proxied** (orange) | images / CDN |

> App records are **DNS-only** — Fly terminates its own TLS. The `images.` record
> is **proxied** — that's what gives edge caching, and R2 sets it up automatically.

---

## Tasks

### 1. Buy domain at Infomaniak
- [x] Register `waerweiss.ch` in the Infomaniak Manager. ✅ **Done**

### 2. Add the domain to Cloudflare
- [ ] Cloudflare dashboard → **Add a site** → enter `waerweiss.ch`.
- [ ] Choose the **Free** plan.
- [ ] Copy the **two nameservers** Cloudflare shows (e.g. `xxx.ns.cloudflare.com`,
      `yyy.ns.cloudflare.com`).

### 3. Point Infomaniak's nameservers to Cloudflare
> The **only** thing left to do at Infomaniak.
- [ ] Infomaniak Manager → `waerweiss.ch` → **DNS / Nameservers**.
- [ ] Replace Infomaniak's default nameservers with the **two Cloudflare
      nameservers** from Task 2.
- [ ] Save and wait for Cloudflare to email that the domain is **Active**
      (minutes to a few hours).

> After this, **all DNS lives in the Cloudflare dashboard.** Infomaniak stays only
> the registrar (ownership + renewals).

### 4. Route the app to Fly.io (app: `along-quiz`)
- [ ] Request certificates:
  ```bash
  fly certs add waerweiss.ch
  fly certs add www.waerweiss.ch     # optional
  fly ips list                        # note IPs if using A/AAAA at apex
  ```
- [ ] In **Cloudflare → DNS**, add the records Fly asks for:
  - `www` → **CNAME** → `along-quiz.fly.dev`
  - apex `waerweiss.ch` → **A/AAAA** to the Fly IPs (or CNAME at apex).
- [ ] Set **all app records to DNS-only (grey cloud)**.
- [ ] Confirm the cert is issued:
  ```bash
  fly certs show waerweiss.ch
  ```

### 5. Connect the images domain to R2
- [ ] Cloudflare → **R2** → your bucket → **Settings** → **Public access** →
      **Custom Domains** → **Connect Domain**.
- [ ] Enter `images.waerweiss.ch`.
- [ ] Let Cloudflare auto-create the proxied CNAME + TLS cert (a few minutes).
- [ ] *(Recommended)* Set aggressive caching — object `Cache-Control:
      public, max-age=31536000, immutable` on upload, or a Cloudflare **Cache
      Rule** for `images.waerweiss.ch` with a long Edge TTL.

### 6. Update the app config
The R2 public URL comes from the **`R2_PUBLIC_BASE_URL`** env var — read in
[`config/runtime.exs`](../config/runtime.exs) and used by
[`lib/quiz/storage/r2.ex`](../lib/quiz/storage/r2.ex) `url/1`.
- [ ] Point it at the custom domain (restarts the app):
  ```bash
  fly secrets set R2_PUBLIC_BASE_URL="https://images.waerweiss.ch" -a along-quiz
  ```

### 7. Verify
- [ ] `https://waerweiss.ch` loads the app with a valid certificate.
- [ ] `https://images.waerweiss.ch/<some-key>` serves an image with a valid cert.
- [ ] Image response header shows `cf-cache-status: HIT` on a repeat request
      (confirms edge caching).

---

## Next action
You're done with Task 1. **Task 2:** add `waerweiss.ch` as a site in Cloudflare
and grab the two nameservers.
