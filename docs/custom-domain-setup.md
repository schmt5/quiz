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
- [x] Cloudflare dashboard → **Add a site** → enter `waerweiss.ch`. ✅ **Done**
- [x] Choose the **Free** plan. ✅ **Done**
- [x] Copy the **two nameservers** Cloudflare shows: `jarred.ns.cloudflare.com`,
      `treasure.ns.cloudflare.com`. ✅ **Done**

### 3. Point Infomaniak's nameservers to Cloudflare
> The **only** thing left to do at Infomaniak.
- [x] Infomaniak Manager → `waerweiss.ch` → **DNS / Nameservers**. ✅ **Done**
- [x] Replace Infomaniak's default nameservers with the **two Cloudflare
      nameservers** from Task 2. ✅ **Done**
- [x] Save and wait for Cloudflare to email that the domain is **Active**
      (minutes to a few hours).

> After this, **all DNS lives in the Cloudflare dashboard.** Infomaniak stays only
> the registrar (ownership + renewals).

### 4. Route the app to Fly.io (app: `along-quiz`)
- [x] Request certificates: ✅ **Done**
  ```bash
  fly certs add waerweiss.ch
  fly certs add www.waerweiss.ch
  ```
- [x] In **Cloudflare → DNS**, added the records Fly asked for (A + AAAA for
      both hosts, not CNAME): ✅ **Done**
  - `waerweiss.ch` → **A** → `66.241.125.246`
  - `waerweiss.ch` → **AAAA** → `2a09:8280:1::12f:d6dc:0`
  - `www.waerweiss.ch` → **A** → `66.241.125.246`
  - `www.waerweiss.ch` → **AAAA** → `2a09:8280:1::12f:d6dc:0`
- [x] Set **all app records to DNS-only (grey cloud)**. ✅ **Done**
- [x] Confirm the cert is issued: ✅ **Done** — both `waerweiss.ch` and
      `www.waerweiss.ch` show `Status = Issued` / verified via
      `fly certs check <host>`.

### 5. Connect the images domain to R2
- [x] Cloudflare → **R2** → your bucket → **Settings** → **Public access** →
      **Custom Domains** → **Connect Domain**. ✅ **Done**
- [x] Enter `images.waerweiss.ch`. ✅ **Done**
- [x] Let Cloudflare auto-create the proxied CNAME + TLS cert (a few minutes). ✅ **Done**
- [ ] *(Recommended, skipped for now)* Set aggressive caching — object
      `Cache-Control: public, max-age=31536000, immutable` on upload, or a
      Cloudflare **Cache Rule** for `images.waerweiss.ch` with a long Edge TTL.

### 6. Update the app config
The R2 public URL comes from the **`R2_PUBLIC_BASE_URL`** env var — read in
[`config/runtime.exs`](../config/runtime.exs) and used by
[`lib/quiz/storage/r2.ex`](../lib/quiz/storage/r2.ex) `url/1`.
- [x] Point it at the custom domain (restarts the app): ✅ **Done**
  ```bash
  fly secrets set R2_PUBLIC_BASE_URL="https://images.waerweiss.ch" -a along-quiz
  ```

### 7. Verify
- [x] `https://waerweiss.ch` loads the app with a valid certificate. ✅ **Done**
- [x] `https://images.waerweiss.ch/<some-key>` serves an image with a valid cert. ✅ **Done**
- [x] Image response header shows `cf-cache-status: HIT` on a repeat request
      (confirms edge caching). ✅ **Done**

---

## Next action
All tasks are complete (caching step in Task 5 skipped by choice). The domain
is fully live: `waerweiss.ch` and `www.waerweiss.ch` serve the app from
Fly.io with valid certs, and `images.waerweiss.ch` serves R2 with edge
caching.
