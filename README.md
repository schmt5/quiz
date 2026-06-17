# Quiz

A live, host-driven quiz platform built with Phoenix LiveView. A host authors a
quiz, opens a run with a join code (and QR code), participants join from their
phones without an account, and the host advances questions, corrects answers,
and publishes a leaderboard in real time.

## Local development

* Run `mix setup` to install dependencies, create and migrate the database, and
  build assets.
* Start the server with `mix phx.server` (or `iex -S mix phx.server`).

Then visit [`localhost:4000`](http://localhost:4000).

Run the test suite with `mix test`, and `mix precommit` before committing
(compiles with warnings as errors, checks unused deps, formats, runs tests).

## Deployment

Production configuration is read at runtime from environment variables
(`config/runtime.exs`). Build a release with `mix release` and start it with
`PHX_SERVER=true`.

### Required (prod)

| Variable | Description |
| --- | --- |
| `DATABASE_URL` | Postgres URL, e.g. `ecto://USER:PASS@HOST/DATABASE` |
| `SECRET_KEY_BASE` | Cookie/secret signing key — generate with `mix phx.gen.secret` |
| `PHX_HOST` | Public hostname; used for generated URLs and the QR join link |
| `PHX_SERVER` | Set to `true` to start the HTTP endpoint under a release |

### Optional

| Variable | Default | Description |
| --- | --- | --- |
| `PORT` | `4000` | HTTP listen port |
| `POOL_SIZE` | `10` | Database connection pool size |
| `ECTO_IPV6` | — | Set to `true`/`1` to connect to the database over IPv6 |
| `DNS_CLUSTER_QUERY` | — | DNS query for clustering nodes |

### Object storage (uploads)

Image uploads (e.g. pin-on-image questions) use a pluggable storage adapter. By
default they are written to local disk; set the Cloudflare R2 variables below to
switch to R2 (S3-compatible). **All five must be set together** — the adapter
activates on `R2_ACCESS_KEY_ID` and requires the rest.

| Variable | Description |
| --- | --- |
| `R2_ACCESS_KEY_ID` | R2 access key id |
| `R2_SECRET_ACCESS_KEY` | R2 secret access key |
| `R2_BUCKET` | Target bucket name |
| `R2_ENDPOINT` | R2 S3 endpoint host, e.g. `<account-id>.r2.cloudflarestorage.com` |
| `R2_PUBLIC_BASE_URL` | Public base URL the stored objects are served from |

### TLS

Production forces SSL and sets HSTS (`config/prod.exs`), so the app must sit
behind TLS — either terminate TLS at a proxy that forwards `x-forwarded-proto`,
or configure HTTPS on the endpoint directly.
