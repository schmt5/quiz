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

2. **Size it up to a dedicated, multi-core CPU.** Shared CPUs get throttled under
   sustained load; dedicated cores give guaranteed, predictable performance.

   The bottleneck is **CPU during render/diff bursts**, not RAM (see below), so
   buy **cores**, not memory. Recommended by safety margin:
   - `performance-2x` (2 cores, 4 GB) — comfortable margin, the sensible default.
   - `performance-4x` (4 cores, 8 GB) — maximum insurance; pick this if you want
     zero worry and don't care about the extra cost (~$60 vs ~$30 for the 14-day
     window).
   - `performance-1x` (1 core, 2 GB) — the bare minimum; leaves no CPU headroom
     for the render burst. Avoid for a high-stakes run.
   ```sh
   fly scale vm performance-4x -a along-quiz
   ```

   **Why cores, not RAM:** each player is a tiny (few-KB) LiveView process, so
   300 connections use single-digit MB — RAM sits idle. But when the host reveals
   a question or publishes grading, one PubSub broadcast wakes **all 300 processes
   at once**, and each re-renders its template and computes a diff. That's 300
   CPU-bound renders in the same instant. The BEAM spreads them across every
   available core, so more cores clear the burst proportionally faster; extra RAM
   does nothing for it.

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

For **real numbers, run it on the production machine** (your laptop's Postgres ≠
Fly's). The core lives in `Quiz.LoadTest` (Mix-free, like `Quiz.Release`) so it
works inside the release:

```sh
fly ssh console -a along-quiz
# small validation run first:
/app/bin/quiz eval 'Quiz.LoadTest.run(participants: 50, questions: 2)'
# then full load:
/app/bin/quiz eval 'Quiz.LoadTest.run(participants: 300, questions: 5, mode: :herd, subscribers: true)'
```

How the prod run behaves:

- `bin/quiz eval` does **not** attach to the running app — it boots a second,
  separate BEAM process on the same machine (no web server; `PHX_SERVER` is
  unset) that runs the test and **exits by itself** when done. Nothing to clean
  up afterwards.
- That second process opens its **own DB pool (50 connections)**, so Postgres
  sees ~100 connections during the test (web app + test). Expected — don't be
  alarmed in monitoring.
- **Results print to stdout of the SSH session**: one line per phase (JOIN,
  Q1/N answers … with wall time, ok/err counts, latency p50/p95/max), then the
  DB-pool block. Watch `/admin/dashboard` (LiveDashboard) in the browser at the
  same time.
- If you abort mid-run (Ctrl+C) or it crashes, the end-of-run cleanup may not
  execute — delete the leftover "LOAD TEST …" game manually in the app.
- `questions: N` is the number of questions in the throwaway game; every
  simulated participant answers each one. The fixture always creates
  single-choice questions — representative for load, since the expensive parts
  (answer upsert, host COUNT, PubSub broadcast) are the same for every question
  type (free-text is graded later in correction, so it's even cheaper live).

Read the output:

- **`queries over 50ms`** in the DB-pool section > 0 → the pool is saturating;
  raise `POOL_SIZE`. (At 0, the pool is coping.)
- **answer `p95` / `max` latency** climbing into hundreds of ms → contention.
- **`err`** counts > 0 → something actually failed under load.

The test creates real load and throwaway data in the prod DB (cleaned up at the
end) — run it in a quiet window, not while a real quiz is live. Full options:
`mix help quiz.load`.

## If you ever want 2+ machines (NOT for this event)

You'd have to enable clustering first so PubSub spans nodes:

```sh
fly secrets set DNS_CLUSTER_QUERY=along-quiz.internal -a along-quiz
```

This also requires the release to be configured for Erlang distribution
(node name + cookie via `rel/`). **Verify it actually clusters** (e.g.
`Node.list/0` shows the sibling) before trusting it for a live run.
