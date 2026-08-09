# Operations Runbook — along-quiz

How to scale the quiz down between events and bring it back up for the next one.

- **Web app:** `along-quiz` on Fly.io (this repo, configured via `fly.toml`), region `fra`
- **Database:** **Neon** serverless Postgres 18 — project `quiz`, database `neondb`,
  endpoint `ep-dry-pine-b2qq9i49.c-6.eu-central-1.aws.neon.tech`, region AWS
  `eu-central-1` (Frankfurt). Managed in the [Neon console](https://console.neon.tech),
  no config in this repo. The connection string lives in the `DATABASE_URL` Fly secret.
- **Uploads:** Cloudflare R2 (`R2_*` secrets), independent of both.

---

## Database

Neon handles its own lifecycle — there is **nothing to start or stop**. The compute
autosuspends after a few minutes of inactivity and wakes on the first connection
(~1–3 s), so between events the database costs storage only.

Connection setup (see `config/runtime.exs`):

- The app uses the **direct (unpooled)** endpoint. Don't swap in the `-pooler` host
  without also setting `prepare: :unnamed` on the repo — Postgrex's named prepared
  statements break under PgBouncer transaction pooling.
- **TLS is mandatory and enabled in code** (`ssl: true`). Postgrex ignores
  `sslmode=…` in the URL query string, so the `DATABASE_URL` secret is stored
  *without* query parameters.
- `ECTO_IPV6` is deliberately **not set** — Neon's endpoint is IPv4.
- `POOL_SIZE` defaults to 20 per machine. Neon's `max_connections` scales with the
  compute size (~112 at 0.25 CU, ~450 at 1 CU); keep `machines × POOL_SIZE` under it.

### Backups

Neon's Point-in-Time Restore covers the configured history window (check the
retention setting in the console — 1 day on Free, longer on paid plans). For a
manual snapshot before something risky, create a **branch** in the Neon console,
or take a dump:

```bash
pg_dump --format=custom --no-owner --no-privileges \
  "$(fly ssh console --app along-quiz -C 'printenv DATABASE_URL')" \
  --file=quiz-$(date +%F).dump
```

---

## Event-mode setup (what to restore before an event)

This is the configuration the app ran during the last event. See
`docs/scaling-for-event.md` for the reasoning and the full checklist.

### Web app `fly.toml`

```toml
[http_service]
  min_machines_running = 1        # always at least one machine warm

[[vm]]
  cpu_kind = 'performance'
  cpus     = 4
  memory   = '8gb'
```

### Database

- Neon compute autoscaling **max ≥ 2 CU**.
- Open the app once before players arrive so the compute is awake.

---

## Idle-mode setup (current state, between events)

### Web app `fly.toml` (already committed)

```toml
[http_service]
  min_machines_running = 0        # scales fully to zero when idle

[[vm]]
  cpu_kind = 'shared'
  cpus     = 1
  memory   = '1gb'
```

Takes effect on the next `fly deploy`. To apply the VM downsize to the running
machine immediately without a redeploy:

```bash
fly scale vm shared-cpu-1x --memory 1024 --app along-quiz
```

### Database

Nothing to do — Neon autosuspends on its own.

---

## Bring the setup back for the next event

### 1. Restore event-mode `fly.toml`

```toml
[http_service]
  min_machines_running = 1

[[vm]]
  cpu_kind = 'performance'
  cpus     = 4
  memory   = '8gb'
```

### 2. Deploy the web app

```bash
fly deploy --app along-quiz
```

This applies both the `fly.toml` changes and re-warms the machine. The deploy's
`release_command` (`/app/bin/migrate`) runs migrations against Neon; the first
connection may wake a suspended compute, which adds a couple of seconds.

### 3. Smoke-test

```bash
fly status --app along-quiz
```

Then open https://waerweiss.ch and confirm the quiz loads and the join QR works.

---

## Handy checks

```bash
fly status --app along-quiz            # web app machines
fly secrets list --app along-quiz      # DATABASE_URL etc. (values hidden)
```

```bash
# DB reachable from the running release?
# `rpc` runs inside the started node (where Quiz.Repo is supervised);
# `eval` boots a fresh VM without the app started and would fail here.
fly ssh console --app along-quiz -C "/app/bin/quiz rpc 'IO.inspect(Quiz.Repo.query!(\"select version()\"))'"
```

Connection count, compute size and query stats: Neon console → project → Monitoring.

### Creating a host account

Self-service registration is **disabled** (the `/users/register` route is commented
out in `lib/quiz_web/router.ex`), so on a fresh database there is no way to create
the first user through the UI. Do it from the running node — the account is
confirmed immediately, password must be at least 12 characters:

```bash
fly ssh console --app along-quiz -C "/app/bin/quiz rpc 'Quiz.Accounts.register_user(%{name: \"Thierry\", email: \"thierry@whatwedo.ch\", password: \"<min-12-chars>\"}) |> IO.inspect()'"
```

---

## Notes

- Uploads live on Cloudflare R2 (bucket via `R2_*` secrets), independent of the
  database — unaffected by scaling.
- **Legacy:** the old self-hosted Fly Postgres cluster `upg-airy-water-745`
  (3× `shared-cpu-2x` / 4 GB) is retired but **kept stopped** as a rollback target.
  Its volumes still hold the pre-migration data. Destroy it with
  `fly apps destroy upg-airy-water-745` once Neon has proven itself.
  Rollback path: start those machines again and point `DATABASE_URL` back at the
  old cluster.
