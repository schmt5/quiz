# Operations Runbook — along-quiz

How to scale the quiz down between events and bring it back up for the next one.

- **Web app:** `along-quiz` (this repo, configured via `fly.toml`)
- **Postgres:** `upg-airy-water-745` (separate managed Fly app, no config in this repo)
- **Region:** `fra`

---

## Event-mode setup (what to restore before an event)

This is the configuration the app ran during the last event.

### Web app `fly.toml`

```toml
[http_service]
  min_machines_running = 1        # always at least one machine warm

[[vm]]
  cpu_kind = 'performance'
  cpus     = 4
  memory   = '8gb'
```

### Postgres cluster

- **3 machines** — 1 primary + 2 replicas (HA), all `started`
- Size: **`shared-cpu-2x` / 4096 MB** each
- Machine IDs / volumes (as of 2026-06-20):

  | Machine ID       | Name                | Role    | Volume                 |
  |------------------|---------------------|---------|------------------------|
  | `2870947c350618` | icy-resonance-7928  | primary | `vol_4y8o0ej2322qw5er` |
  | `7811e42fe63d18` | summer-sky-3146     | replica | `vol_vz8pq1ko8k2192ev` |
  | `683e623b104dd8` | nameless-voice-6836 | replica | `vol_re10z92w7ekkg0d4` |

---

## Idle-mode setup (current state, between events)

Applied 2026-07-17 after the event.

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

### Postgres — stopped

All 3 machines stopped (`fly machine stop`). **Data is preserved on the volumes**;
only compute is halted. You pay only for volume storage while stopped.

```bash
fly machine stop 2870947c350618 --app upg-airy-water-745   # primary
fly machine stop 7811e42fe63d18 --app upg-airy-water-745   # replica
fly machine stop 683e623b104dd8 --app upg-airy-water-745   # replica
```

---

## Bring the setup back for the next event

### 1. Start Postgres (primary first, then replicas)

```bash
fly machine start 2870947c350618 --app upg-airy-water-745   # primary
fly machine start 7811e42fe63d18 --app upg-airy-water-745   # replica
fly machine start 683e623b104dd8 --app upg-airy-water-745   # replica

# verify all 3 report started / 3/3 checks passing
fly status --app upg-airy-water-745
```

Your data is exactly as you left it — starting stopped machines does not touch
the volumes.

### 2. Restore event-mode `fly.toml`

Edit `fly.toml` back to event values:

```toml
[http_service]
  min_machines_running = 1

[[vm]]
  cpu_kind = 'performance'
  cpus     = 4
  memory   = '8gb'
```

### 3. Deploy the web app

```bash
fly deploy --app along-quiz
```

This applies both the `fly.toml` changes and re-warms the machine.

### 4. Smoke-test

```bash
fly status --app along-quiz
```

Then open https://waerweiss.ch and confirm the quiz loads and the join QR works.

---

## Handy checks

```bash
fly status  --app along-quiz            # web app machines
fly status  --app upg-airy-water-745    # postgres machines
fly machine list --app upg-airy-water-745
fly secrets list --app along-quiz       # DATABASE_URL etc. (values hidden)
```

## Notes

- While Postgres is stopped, the web app will error on any DB access — expected in idle mode.
- Uploads live on Cloudflare R2 (bucket via `R2_*` secrets), independent of Postgres — unaffected by scaling.
- `DATABASE_URL` points the web app at the Postgres app; it does not change when you stop/start machines.
