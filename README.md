# ChatLogger

A pluggable Elixir `:logger` backend for routing exceptions and application logs directly to team chat platforms.

It uses the `Adapter` pattern to format logs properly for Slack, Discord, Telegram, or Zulip.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `chat_logger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chat_logger, "~> 0.1.0"}
  ]
end
```

## Configuration

In your `config/prod.exs` or `config/runtime.exs`:

```elixir
config :logger,
  backends: [:console, ChatLogger]

config :logger, ChatLogger,
  level: :warning, # Recommended: only send warnings/errors to chat
  project_name: "My App Production",
  adapters: [
    {ChatLogger.Adapters.Slack, url: System.get_env("SLACK_WEBHOOK_URL")},
    {ChatLogger.Adapters.Discord, url: System.get_env("DISCORD_WEBHOOK_URL")}
  ]
```

## Supported Adapters

### Zulip (Recommended for multiple projects)

Zulip is highly recommended because of its Stream/Topic threading model, which prevents notification spam.

```elixir
{ChatLogger.Adapters.Zulip, 
  url: "https://zulip.example.com",
  bot_email: "bot@example.com", 
  bot_api_key: "XXX",
  stream: "alerts",
  topic: "my-app-production" # Defaults to project_name
}
```

### Telegram (Recommended for instant mobile push)

```elixir
{ChatLogger.Adapters.Telegram, 
  bot_token: "XXX:YYY",
  chat_id: "-10012345678"
}
```

### Discord / Slack

Both use standard generic Incoming Webhook URLs.

```elixir
{ChatLogger.Adapters.Discord, url: "https://discord.com/api/webhooks/..."}
# or
{ChatLogger.Adapters.Slack, url: "https://hooks.slack.com/services/..."}
```

## Advanced Filtering

Because `chat_logger` integrates with the standard Elixir `Logger` backend system, you can ignore specific noisy errors before they reach chat:

```elixir
# config/prod.exs
# E.g., Don't send Phoenix typical 404s to chat
config :logger, ChatLogger,
  level: :warning,
  project_name: "App",
  adapters: [...],
  metadata_filter: [application: :my_app] # Standard logger filter
```
