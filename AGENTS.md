# log_out — contributor and agent guide

`log_out` is an Elixir logger backend that ships logs to chat services (Zulip, Slack,
Discord, Telegram). Published to Hex as `log_out`.

## Layout

- `lib/log_out.ex` — the logger backend; `lib/log_out/adapter.ex` — the adapter behaviour.
- `lib/log_out/adapters/*.ex` — one adapter per service.
- `test/` — ExUnit.

## Commands

```bash
mix deps.get
mix test
mix format --check-formatted
```

## Rules

- Adapters implement the `LogOut.Adapter` behaviour and must never raise into the caller's logging path.
- HTTP goes through `Req`. No other HTTP client.
- Public config keys are API: add, don't rename; note changes in the README.
- Every adapter change needs a test.
- Keep it small: reuse before adding, delete before extending.

## Releasing

Bump `version` in `mix.exs`, then the maintainer runs `mix hex.publish`. Agents prepare the PR but never publish.
