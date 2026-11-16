[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/pomerium-1?utm_medium=integration&utm_source=button&utm_campaign=pomerium)

# Pomerium on Railway

Deploys [Pomerium](https://github.com/pomerium/pomerium) **v0.34.1** (Pomerium Core, Apache-2.0), an identity-aware reverse proxy, as a Railway template. Pomerium signs users in and checks a policy on every request before passing it to the app behind it.

## What it deploys

One service built from this repo's `Dockerfile`:

- `FROM pomerium/pomerium:debug-v0.34.1@sha256:ac62ca9f…` (the official image's `debug` variant: the same Pomerium binary, plus a shell for `start.sh`).
- `start.sh` writes Pomerium's `config.yaml` from environment variables and starts Pomerium in all-in-one mode (authenticate, authorize, databroker and proxy in one process) on `$PORT` over plain HTTP. Railway's edge terminates TLS.
- A volume at `/data` holds the databroker (file storage, so sessions survive redeploys) and the secrets generated on first boot: shared secret, cookie secret and the JWT signing key.
- Health check: `/ping`.

Sign-in uses Pomerium's free [hosted authenticate service](https://www.pomerium.com/docs/capabilities/hosted-authenticate-service) by default (email/password, Google or GitHub), so you don't have to register an OAuth client first. You can switch to your own identity provider (see below).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ALLOWED_EMAILS` | (asked at deploy) | Comma-separated emails allowed through. Required unless `ALLOWED_DOMAINS` is set |
| `ALLOWED_DOMAINS` | empty | Comma-separated email domains allowed through, e.g. `example.com` |
| `UPSTREAM_URL` | empty | The app to protect, e.g. `http://my-app.railway.internal:3000`. Empty shows a built-in "signed in" page |
| `PORT` | `8080` | Port Pomerium listens on |
| `POMERIUM_HOST` | `RAILWAY_PUBLIC_DOMAIN` | Set it when you serve Pomerium on a custom domain |
| `PRESERVE_HOST_HEADER` | `false` | Pass the original `Host` header to the upstream |
| `EXTRA_ROUTES` | empty | Extra Pomerium routes as YAML list items (each with its own `policy`), appended to `routes:` |
| `SHARED_SECRET`, `COOKIE_SECRET`, `SIGNING_KEY` | generated on `/data` | Override only if you need fixed values |
| `IDP_PROVIDER`, `IDP_PROVIDER_URL`, `IDP_CLIENT_ID`, `IDP_CLIENT_SECRET`, `AUTHENTICATE_SERVICE_URL` | unset | Use your own identity provider instead of the hosted one. `AUTHENTICATE_SERVICE_URL` needs its own hostname, e.g. a second custom domain on this service |
| `DATABROKER_STORAGE_TYPE`, `DATABROKER_STORAGE_CONNECTION_STRING` | `file`, `file:///data/databroker` | Switch to `postgres` and a `${{Postgres.DATABASE_URL}}` reference to run several replicas |

Any other [Pomerium setting](https://www.pomerium.com/docs/reference) can be set as an environment variable with its upper-case name.

## Updates

Railway notifies everyone who deployed this template when a change is merged to `main`. Each update bumps the pinned image (version and digest) and adds an entry to [CHANGELOG.md](CHANGELOG.md), with breaking changes listed first. Read it before you apply an update.

## Run locally

```sh
docker build -t pomerium-railway .
docker run -p 8080:8080 -v pomerium-data:/data \
  -e POMERIUM_HOST=pomerium.localhost.pomerium.io \
  -e ALLOWED_EMAILS=you@example.com pomerium-railway
```

Pomerium expects HTTPS on the route's hostname, so for a full sign-in test put it behind a TLS proxy, as Railway does.
