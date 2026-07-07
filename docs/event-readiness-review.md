# Event-Readiness Review (~300 participants)

Code inspection of the quiz app ahead of the big live event. Focus: **running
correctly matters more than features**. Every finding below was verified
against the code (file references included); a few scary-sounding hypotheses
were checked and dismissed — see "Verified non-issues" at the end.

**Verdict:** the app is architecturally sound — authorization, enrollment
races, scoring math, and XSS handling all check out. The WebSocket origin
check on the custom domain, the participant-side crash protection, the
grading-publish burst, and the remove-team gap have since been fixed (marked
✅ below). The main remaining risk is the fly.toml scaling steps, which are
documented but not yet applied; the rest is monitoring and the load test.

---

## A. Critical — do/verify before the event

### A1. Apply the fly.toml scaling steps (documented, not applied)

`fly.toml` is still in idle config: `min_machines_running = 0`,
`auto_stop_machines = 'stop'`, `shared-cpu-1x` / 1 GB (fly.toml:23–36).
The checklist in [scaling-for-event.md](scaling-for-event.md) (pin to 1
machine, `performance-2x`/`-4x`, `min_machines_running = 1`) exists but has
not been executed. Without it: cold start when the first players arrive, and
a single shared CPU core choking on the 300-process render burst every time
the host advances a question.

### A2. WebSocket origin check vs. `waerweiss.ch` — ✅ fixed in config

There was **no `check_origin` setting** in config, so Phoenix fell back to
checking WebSocket origins against `PHX_HOST` (`along-quiz.fly.dev`), which
rejected the LiveView socket on `waerweiss.ch` — participants hung on the
"Verbinde …" spinner.

**Fixed:** `config/runtime.exs` now sets an explicit list covering
`https://waerweiss.ch`, `https://www.waerweiss.ch`, and
`https://along-quiz.fly.dev`.

**Remaining verification (after the next deploy):** join as a participant
**from a phone via `https://waerweiss.ch`** and confirm the question actually
updates when the host advances. Repeat for `www.`.

### A3. QR code and "go to <host>" text follow `PHX_HOST` — ✅ fixed

The host screen's QR code and the displayed join host are built from
`QuizWeb.Endpoint.url()` ([host.ex:493–509](../lib/quiz_web/live/run_live/host.ex)).
`PHX_HOST` in fly.toml is now set to `waerweiss.ch`, so the QR on the beamer
points to the custom domain; A2's `check_origin` list covers all hosts.

### A5. Monitoring in prod — ✅ LiveDashboard mounted for logged-in users

LiveDashboard is now mounted at **`/admin/dashboard`** in every environment,
gated by the normal login ([router.ex](../lib/quiz_web/router.ex)). Public
registration is disabled, so every account is a quiz master — no extra secret
needed. (If registration ever opens up, the dashboard needs its own gate: it
exposes process state, ETS tables, and config.)

During the run, watch `https://waerweiss.ch/admin/dashboard` (Home →
memory/atoms; Metrics → LiveView/Repo timings; Processes) alongside
`fly logs -a along-quiz`. There is still no error tracker (Sentry etc.) —
the dashboard + logs are the monitoring for this event.

### A6. Run the load test against prod-like infra

After resizing the VM, run the existing harness (see scaling-for-event.md):

```sh
mix quiz.load --participants 300 --questions 5 --mode herd --subscribers
```

against the Fly machine / prod DB, and check pool queue times and p95
latencies. This exercises exactly the hot paths listed in section C.

---

## B. Bugs (correctness)

Both findings below have since been fixed.

### B5. Participant LiveView has no catch-all `handle_info` — ✅ fixed

`PlayLive.Play` handled exactly the four broadcast types of the day; the host
screen has a defensive catch-all precisely so "a new message type can never
crash the presenter screen". Without it, a future broadcast type would crash
**all 300 participant processes simultaneously**.

**Fixed:** catch-all `handle_info` added to the participant LiveView
([play.ex:314](../lib/quiz_web/live/play_live/play.ex)), plus a regression
test that sends an unknown message and asserts the view survives.

### B6. `publish_grading` is not idempotent — ✅ fixed

It always wrote and always broadcast; a double-click published twice → every
participant recomputed the leaderboard twice (see C1).

**Fixed:** `publish_grading` now returns `{:ok, game}` without writing or
broadcasting when `grading_published` is already set
([play.ex:513](../lib/quiz/play.ex)), covered by a `refute_received` test.

---

## C. Performance / thundering-herd hot spots

The DB pool is 50 and Postgres is oversized, so none of these are expected
to fail outright — but they are the places that buckle first. All are
exercised by `mix quiz.load` (A6).

### C1. Publishing the grading → 300 simultaneous leaderboard loads — ✅ fixed

On the `grading_published` broadcast, **every** participant LiveView used to
call `Play.leaderboard/1` (all answer rows + all participants, ranked in
memory) at the same instant — 300 concurrent copies of a ~6,000-row query,
the single heaviest burst in the app, at the emotional climax of the evening.

**Fixed:** the leaderboard is computed **once** inside `publish_grading` and
shipped in the broadcast payload
(`{:grading_published, game, leaderboard}`, [play.ex:521](../lib/quiz/play.ex));
participant, host, and leaderboard views render straight from the payload.
The on-demand query path remains only as the reconnect fallback.

### C2. Every host click → ~900 simultaneous queries

Each `status_changed` broadcast (start / reveal / next / previous) makes all
300 participant LiveViews run `current_question` + `question_numbering` +
`get_answer` ([play_live/play.ex:298–317](../lib/quiz_web/live/play_live/play.ex)).
~900 near-identical queries hit the pool at the same instant, ~20+ times
during the quiz. Pool 50 should absorb it (verify via A6); the optional
improvement is to include the question and numbering in the broadcast so
participants don't query at all.

---

## D. Hardening / event-day risks

### D2. No enrollment cap or rate limiting

`get_game_by_join_code` and `enroll` are unauthenticated and unthrottled
([play.ex:175–248](../lib/quiz/play.ex)). A prankster can script-enroll
hundreds of fake teams, polluting the roster and leaderboard (and each
enrollment broadcasts to everyone). Cheap insurance: cap participants per
game (e.g. reject enrollment past 400).

### D3. Defense-in-depth asserts missing in `submit_answer`

`submit_answer` trusts `participant` and `question` from socket assigns and
never asserts `participant.game_id == game.id` or
`question.game_id == game.id` ([play.ex:325](../lib/quiz/play.ex)). Today's
call sites load both correctly; the asserts make future call sites unable to
cross-contaminate games. Two lines.

### D5. Question images depend on R2/Cloudflare at show time

Media is served from `images.waerweiss.ch` (R2 public bucket). If R2 or the
CDN misbehaves, images 404 with no fallback. **Warm the cache** before the
event by clicking through every question in the preview from the venue
network — repeat views then serve from Cloudflare's edge
(`cf-cache-status: HIT`).

---

## E. Verified non-issues

Checked explicitly so nobody re-litigates them under stress:

- **Authorization is solid.** All host/correction/leaderboard routes require
  login *and* every mount goes through owner-scoped
  `Games.get_game!(scope, …)`; participants are identified by a signed
  `Phoenix.Token` that is verified against the game on restore.
- **Tie ranking is exact.** Scores are sums of 1.0 / 0.5 / 0.0 — all exactly
  representable floats, so the `==` tie comparison in `with_ranks/1` is safe.
- **Enrollment name races are handled** via the unique index on
  `(game_id, name)` plus a retry that maps constraint errors to
  `:name_taken` ([play.ex:223–246](../lib/quiz/play.ex)).
- **The correction view does not stampede**: it ignores `answer_submitted`
  broadcasts for other questions
  ([question.ex:226](../lib/quiz_web/live/correction_live/question.ex)).
- **XSS is covered**: question descriptions pass through a strict allowlist
  scrubber; participant names are HEEx-escaped everywhere they render.
- **Sequence questions grade correctly**: the shuffle is applied to a display
  copy only; scoring always uses the canonical question.
- **Answer indexes are adequate**: `answers(question_id)` +
  unique `(participant_id, question_id)`; participants unique on
  `(game_id, name)`.

---

## Suggested order of work

| # | Action | Type | Effort | Status |
|---|--------|------|--------|--------|
| 1 | A2 `check_origin` + A3 `PHX_HOST` = `waerweiss.ch` | config | small | ✅ done (phone test pending after deploy) |
| 2 | A1 apply fly.toml scaling steps | ops | small | open |
| 3 | B5 catch-all `handle_info` in participant LiveView | code | 1 line | ✅ done |
| 4 | C1 leaderboard computed once, shipped in broadcast (incl. B6 idempotency) | code | medium | ✅ done |
| 5 | "remove team" action on host roster | code | medium | ✅ done |
| 6 | A5 LiveDashboard in prod (login-gated) | code | small | ✅ done |
| 7 | A6 load test on prod-like target | ops | — | open |
