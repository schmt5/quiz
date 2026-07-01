# Scaling for a Big Event (~300 participants)

Checklist to prepare `along-quiz` for a live run with ~300 concurrent players.
Do this **shortly before** the event and scale back down afterwards.

## TL;DR

Run **one bigger, always-on app machine**. Don't touch Postgres — it's already
oversized for this. The single-machine setup avoids a PubSub bug (see below).

## Current state (for reference)

| Component | What's deployed | Notes |
|---|---|---|
| App `along-quiz` | 2× `shared-cpu-1x` / 1 GB, both auto-stopped | `min_machines_running = 0` → cold start |
| DB `upg-airy-water-745` | 3-node Postgres Flex (1 primary + 2 replicas), `shared-cpu-2x` / 4 GB each | Already plenty — **do not scale up** |
| DB pool | `POOL_SIZE` default now **50** (`config/runtime.exs`) | Was 10; hard-coded to 50 |

## Why one big machine, not two small ones

**Clustering is OFF.** `DNSCluster` is wired into `lib/quiz/application.ex` but only
activates when the `DNS_CLUSTER_QUERY` env var is set — and it isn't. Phoenix
PubSub then only propagates **within a single BEAM node**. All realtime messages
(`status_changed`, `grading_published`, `answer_submitted`, `participant_joined`)
go through one PubSub topic per game, so if two nodes ever both serve players,
those on node B never receive broadcasts fired on node A.

**This is a latent edge case, not a load problem.** Fly's proxy only starts the
second machine when the running one crosses the concurrency `soft_limit` (1000
connections in `fly.toml`). 300 players ≈ 300 WebSocket connections — well under
that — so under normal operation Fly keeps everyone on a **single** machine and
PubSub works fine. (This is why the 18-person test worked, and why 300 would too.)

The split only happens if a second machine ends up serving traffic for another
reason: **a deploy during the event** (rolling deploys briefly run both), a **host
/ health failover**, or a **manual start**. Pinning to one machine (`fly scale
count 1`) makes that impossible — there's no second node to route to, whatever
happens mid-event. Cheap insurance for a high-stakes live run, not a bug fix.

300 LiveView connections is trivial for a single BEAM node; the only real
constraint is CPU during render/diff bursts, which the dedicated-CPU VM covers.

## Steps to prepare (before the event)

1. **Pin to a single machine.**
   ```sh
   fly scale count 1 -a along-quiz
   ```

2. **Size it up to a dedicated CPU.** Shared CPUs get throttled under sustained
   load; a dedicated core gives predictable performance. `performance-1x` (1
   dedicated core, 2 GB) is enough; `performance-2x` for headroom.
   ```sh
   fly scale vm performance-1x -a along-quiz
   ```

3. **Keep it warm** so the first player doesn't hit a cold start. Edit
   `fly.toml`:
   ```toml
   [http_service]
     min_machines_running = 1   # was 0
   ```
   Then redeploy (or `fly deploy`) to apply the `fly.toml` change.

4. **Confirm `POOL_SIZE` = 50** (already the default in `config/runtime.exs`).
   No action needed unless a `POOL_SIZE` secret/env overrides it — check with:
   ```sh
   fly secrets list -a along-quiz
   ```

## Verify before players arrive

```sh
fly status -a along-quiz          # exactly 1 machine, state = started, size = performance-1x
fly machine list -a along-quiz
```

- Open the app, join as a test participant, advance a question from the host
  screen → the participant screen should update. (Confirms PubSub on one node.)
- Optional: watch `/dashboard` (LiveDashboard) during a dry run — check the Ecto
  pool queue time and memory stay low.

## After the event — scale back down

```sh
fly scale vm shared-cpu-1x --vm-memory 1024 -a along-quiz
# optionally set min_machines_running = 0 again in fly.toml and redeploy
```

## Load testing before the event

There's an in-VM load test that simulates N participants joining + answering,
driving the `Quiz.Play` context directly (no browser). It stresses the parts that
break first: the DB pool, answer upserts, the per-answer host COUNT, and the
PubSub fan-out. It does **not** test the WebSocket/LiveView transport layer.

```sh
# worst case: all 300 submit at the same instant
mix quiz.load --participants 300 --questions 5 --mode herd --subscribers

# realistic: submissions spread over 3s
mix quiz.load --participants 300 --mode jitter --spread 3000 --subscribers
```

Read the output:

- **`queries over 50ms`** in the DB-pool section > 0 → the pool is saturating;
  raise `POOL_SIZE`. (At 0, the pool is coping.)
- **answer `p95` / `max` latency** climbing into hundreds of ms → contention.
- **`err`** counts > 0 → something actually failed under load.

Caveats: run it against a **prod-like target** for meaningful numbers (your laptop's
Postgres ≠ Fly's) — e.g. on the Fly machine via `fly ssh console` then
`/app/bin/quiz eval "Mix.Tasks.Quiz.Load.run([...])"`, or point a local run at a
staging DB. Watch `/dashboard` (LiveDashboard) at the same time. Full options:
`mix help quiz.load`.

## If you ever want 2+ machines (NOT for this event)

You'd have to enable clustering first so PubSub spans nodes:

```sh
fly secrets set DNS_CLUSTER_QUERY=along-quiz.internal -a along-quiz
```

This also requires the release to be configured for Erlang distribution
(node name + cookie via `rel/`). **Verify it actually clusters** (e.g.
`Node.list/0` shows the sibling) before trusting it for a live run.
