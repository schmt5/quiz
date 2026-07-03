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
- [ ] `https://waerweiss.ch` loads the app with a valid certificate.
- [x] `https://images.waerweiss.ch/<some-key>` serves an image with a valid cert. ✅ **Done**
- [x] Image response header shows `cf-cache-status: HIT` on a repeat request
      (confirms edge caching). ✅ **Done**

---

## Next action
You're done with Tasks 1, 2, 3, 5, and 6 (caching step in Task 5 skipped by
choice). If you haven't already, finish **Task 4** (route `waerweiss.ch` /
`www.waerweiss.ch` to Fly.io) — then move to **Task 7: Verify** everything end
to end.
