# LogOut

[![Hex.pm VERSION](https://img.shields.io/hexpm/v/log_out.svg)](https://hex.pm/packages/log_out)
[![Hex.pm LICENSE](https://img.shields.io/hexpm/l/log_out.svg)](https://hex.pm/packages/log_out)

**LogOut** is a pluggable Elixir Logger backend for routing exceptions and application logs directly to team chat platforms.

It uses an `Adapter` pattern to seamlessly format Elixir logs and send them asynchronously to services like **Slack, Discord, Telegram, and Zulip**. 

Because `LogOut` hooks into Elixir's native `:logger` (via `:gen_event`), it integrates perfectly with all normal `Logger.info`, `Logger.error`, and unexpected exception traces across your app. Also, it uses `Task.start/1` to dispatch HTTP requests asynchronously, meaning your Phoenix controllers or background jobs are never blocked by logging.

---

## Installation

Add `log_out` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:log_out, "~> 0.1.0"}
  ]
end
```

## Configuration Basics

`LogOut` runs as an extra backend for Elixir's built-in `:logger`. Configuration goes in **`config/runtime.exs`** (inside a `config_env() == :prod` guard), not `config/prod.exs`.

> **Why `runtime.exs`?** `prod.exs` is evaluated at compile time — before your app boots. If your secrets are set as environment variables at runtime (e.g. Fly.io, Gigalixir, Render), `System.get_env` calls in `prod.exs` will return `nil` and LogOut will silently fail to connect. `runtime.exs` runs after compilation, when environment variables are available.

```elixir
# config/runtime.exs
if config_env() == :prod do
  # 1. Add LogOut to your active backends
  config :logger, backends: [:console, LogOut]

  # 2. Configure LogOut
  config :logger, LogOut,
    # We recommend only forwarding :warning or :error to chat
    level: :warning,
    project_name: "My App Production", # Prefixes the chat messages
    adapters: [
      # You can configure one or multiple adapters to fire simultaneously!
      {LogOut.Adapters.Slack, url: System.get_env("SLACK_WEBHOOK_URL")}
    ]
end
```

## Supported Adapters & Usage

`LogOut` provides four built-in adapters out of the box.

### Slack

Simple webhook-based integration. Create separate channels per project or use one channel with project name prefixes.

```elixir
config :logger, LogOut,
  level: :warning,
  project_name: "My App Production",
  adapters: [
    {LogOut.Adapters.Slack, url: System.get_env("SLACK_WEBHOOK_URL")}
  ]
```

**Multi-Project Setup:**
- Option 1: One channel (e.g., `#prod-alerts`) with different `project_name` per app
- Option 2: Separate channels per project with different webhook URLs

### Discord

Similar to Slack, uses incoming webhook URLs.

```elixir
config :logger, LogOut,
  adapters: [
    {LogOut.Adapters.Discord, url: System.get_env("DISCORD_WEBHOOK_URL")}
  ]
```

### Telegram

Great for instant mobile push notifications.

```elixir
config :logger, LogOut,
  adapters: [
    {LogOut.Adapters.Telegram,
      bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
      chat_id: "-10012345678",
      # message_thread_id: 123 (Optional: if using Telegram Topics in groups)
    }
  ]
```

### Zulip

Unique Stream/Topic threading model that keeps logs organized across multiple projects and log types.

**Prerequisites:**
1. Create a bot in Zulip: Settings → Personal settings → Bots → Add a new bot
2. Create stream(s) in Zulip: Gear icon → Manage streams → Create stream
3. Subscribe the bot to the stream(s)

```elixir
config :logger, LogOut,
  project_name: "MyApp Production",
  adapters: [
    {LogOut.Adapters.Zulip,
      url: "https://zulip.example.com",
      bot_email: "bot@example.com",
      bot_api_key: System.get_env("ZULIP_API_KEY"),
      stream: "alerts",  # Must exist in Zulip
      # topic defaults to project_name if not specified
      topic: "my-app-production"
    }
  ]
```

**Note:** Streams must be created manually in Zulip before LogOut can post to them. If a stream doesn't exist, LogOut will log a warning and silently skip posting (your app won't crash).

**Dynamic Topics:**

You can override the topic on a per-log basis using Logger metadata — no
extra Logger config (like a backend `:metadata` allowlist) is required, the
key just needs to be passed at the call site:

```elixir
# Goes to configured default topic
Logger.info("User logged out: user@example.com")

# Goes to "errors" topic in the same stream
Logger.error("Database connection failed", zulip_topic: "errors")

# Goes to "security" topic in the same stream
Logger.warning("Failed login attempt", zulip_topic: "security")
```

`zulip_topic` is only honored when it's a non-empty binary. A value over
Zulip's 60-character topic limit is truncated rather than rejected; a
missing, blank, or non-binary value (e.g. an atom) falls back to the
configured `:topic`/`:project_name` chain instead of dropping the message.

**Multi-Project Setup:**

Recommended approach: Use stream names for projects, topics for log types:

```elixir
# Project A config
config :logger, LogOut,
  project_name: "ProjectA",
  adapters: [{LogOut.Adapters.Zulip, stream: "ProjectA", topic: "alerts", ...}]

# Project B config
config :logger, LogOut,
  project_name: "ProjectB",
  adapters: [{LogOut.Adapters.Zulip, stream: "ProjectB", topic: "alerts", ...}]
```

This keeps each project's logs in separate streams while allowing dynamic topics within each stream.

---

## Filtering Noise

If a specific library or background worker is generating `Logger.error` entries that you want to ignore, you can use Elixir's built-in Logger filtering system:

```elixir
# Filter out noisy events before they ever reach LogOut
config :logger, LogOut,
  level: :warning,
  project_name: "App",
  adapters: [...],
  metadata_filter: [application: :my_app] # Only send logs from :my_app
```

## Writing Your Own Adapter

If you need to send logs to Mattermost, Teams, or an internal HTTP endpoint, writing a custom adapter is trivial.

```elixir
defmodule MyMattermostAdapter do
  @behaviour LogOut.Adapter

  @impl true
  def send_message(log_event, config) do
    # log_event = %{level: :error, msg: {:string, "Bad connection"}, meta: %{...}}
    
    # Optional helpers bundled with LogOut
    formatted_msg = LogOut.format_message(log_event)
    emoji = LogOut.get_emoji(log_event.level)

    # Use any HTTP client to fire off the web request
    Req.post!("https://mattermost...", json: %{text: formatted_msg})
  end
end
```

Then just add your module to the adapters list:
```elixir
config :logger, LogOut,
  adapters: [
    {MyMattermostAdapter, some_config_key: "value"}
  ]
```

## Documentation

Full documentation can be found at [https://hexdocs.pm/log_out](https://hexdocs.pm/log_out).
