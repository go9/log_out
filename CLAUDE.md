# log_out

@~/Sites/agent-conventions/CLAUDE.md

## What this is

Elixir Hex package — a Logger backend that ships log messages to Zulip. Library only, no Fly app, no database.

## Repository

GitHub: `go9/log_out` (private)
Tracker: self (`go9/log_out`)

## Running locally

```bash
cd ~/Sites/log_out
mix deps.get
mix test
```

## Release

This is a Hex package, not a deployed service. Publish to Hex via:

```bash
mix hex.publish
```

(Requires Hex auth. Coordinate version bumps with consumers — `enventory_new`, `foodfeed`, etc.)
