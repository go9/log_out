# LogOut — agent instructions

LogOut is a small, public Elixir Hex package (`log_out`, MIT): a pluggable
`:logger` backend that forwards application logs and exceptions to team chat
platforms. It hooks Elixir's native `:logger` via `:gen_event` and dispatches
each event to one or more **adapters** (Zulip, Slack, Discord, Telegram, or a
custom one) using `Task.start/1`, so a slow webhook never blocks a caller.
Library only — no server, no database, no deploy target. Consumers in this
portfolio: **flicker** (Hex, `~> 0.1.4`), **enventory_new** and **skusync**
(both pinned to a git ref on `go9/log_out`). Because it is published on
hex.pm, unknown third parties may also depend on it.

## Dev commands

```bash
mix deps.get
mix test
mix format          # .formatter.exs is checked in
mix docs            # ExDoc; main page is README.md
```

Elixir `~> 1.18`. Runtime deps: `req` only (`~> 0.5.10 or ~> 0.6`) —
**never add HTTPoison/Tesla/httpc**. `ex_doc` is dev-only. There is no demo
app, no `.env`, and no `mix setup` alias — `mix deps.get && mix test` is the
whole loop. Tests avoid live HTTP by passing a stub adapter module that sends
the forwarded level back to the test process (see
`LogOutTest.EchoAdapter` in `test/log_out_test.exs`) — follow that pattern
rather than hitting a real webhook.

## Release

This is a **Hex package, not a deployed service.** Nothing auto-deploys on
push; there is no server and no CI workflow in this repo.

```bash
mix hex.publish      # requires Hex auth; publishing is irreversible-ish
```

Ritual for a release:

1. Bump `version:` in `mix.exs` (single source of truth — there is no
   `@version` module attribute and no `CHANGELOG.md` in this repo yet).
2. Publish with `mix hex.publish`, then tag the commit.
3. Coordinate with consumers. flicker tracks Hex (`~> 0.1.4`), but
   `enventory_new` and `skusync` pin **git refs**, so a Hex release does not
   reach them — their `mix.exs` ref must be bumped separately.

Never publish from an agent session without explicit human approval.

## Durable gotchas (the public API is a contract)

- **Public API surface** — changing or removing any of these breaks consumers:
  - `LogOut` itself (the `:gen_event` backend registered as
    `config :logger, backends: [:console, LogOut]`).
  - `LogOut.Adapter` — the `@callback send_message(log_event :: map(), config
    :: keyword())` behaviour. Third parties implement it; the callback's shape
    is frozen.
  - Adapter helpers used by custom adapters: `LogOut.format_message/1`,
    `LogOut.format_mfa/1`, `LogOut.get_emoji/1`.
  - Built-in adapters `LogOut.Adapters.{Zulip,Slack,Discord,Telegram}`.
  - The `log_event` map shape passed to adapters:
    `%{level: atom, msg: {:string, binary}, meta: map}`.
- **Config keys** live under `config :logger, LogOut, ...` and are read in
  `configure/1`: `:level`, `:levels`, `:adapters`, plus whatever the adapters
  read from the merged config (`:project_name`, and per-adapter `:url`,
  `:bot_email`, `:bot_api_key`, `:stream`, `:topic`, `:bot_token`, `:chat_id`,
  `:message_thread_id`). Adapter config is `Keyword.merge`d **over** the
  top-level config, so per-adapter keys win.
- **`:level` vs `:levels` are different semantics.** `:level` is a *minimum
  threshold* (`Logger.compare_levels/2`). `:levels` is an *exact allowlist* and
  takes precedence when set — it's the only way to forward `:warning` without
  also forwarding `:error`.
- **`:warn` is normalized to `:warning`** before it reaches
  `Logger.compare_levels/2`. This is deliberate: older deps still emit `:warn`,
  and passing it through made Elixir log its own deprecation warning on *every*
  event, flooding the adapters. Do not remove `normalize_level/1`.
- **Config belongs in `config/runtime.exs`**, not `config/prod.exs` — README
  documents this and consumers rely on it. `prod.exs` is evaluated at compile
  time, so `System.get_env/1` returns `nil` and the backend silently no-ops.
- **Adapters fail soft by design.** Each adapter returns `:ok` and skips
  posting when required config is missing (see `LogOut.Adapters.Zulip`), and a
  nonexistent Zulip stream is a warning, not a crash. A logger backend must
  never take down the host app — keep it that way.
- **Known doc drift:** the README documents a `metadata_filter:` option, but
  **no such option is implemented** in `lib/`. Either implement it or correct
  the README; do not assume it works.

## Workflow

- Tracker = **Flicker Tickets** (`flicker` CLI). GitHub is code-only —
  branches, PRs, review. Never file tickets or plans on GitHub.
- `flicker ticket start <id>` before writing code; `flicker ticket complete`
  when merged. Pick up only `selected_for_dev` work unless told otherwise.
- Plans/decisions/status → ticket documents, not new markdown files in this
  repo.
- Work in a dedicated git worktree + branch (`git worktree add
  ../log_out-<task> -b <branch>`); never switch branches in a shared checkout.
- Never push without explicit approval, and **never run `mix hex.publish`**
  without it — this is a public package.
