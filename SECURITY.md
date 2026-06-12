# Security

Bite handles personal health data, so security reports are taken seriously.

## Reporting a vulnerability

Please do not open a public issue for security problems. Email **francescogiannicola1@gmail.com** with a description and, if possible, steps to reproduce. You will get a reply within a few days.

## What is in place today

* Auth: Firebase JWT verified on every worker request.
* User files (lab reports) are encrypted with a per user AES GCM key before they reach storage; the master key lives in Wrangler secrets.
* Secrets are never committed. Public config lives in `wrangler.toml`, secrets are set with `wrangler secret put`.
* The model layer never accesses the database directly; all access goes through typed, validated tools.
