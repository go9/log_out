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

`LogOut` runs as an extra backend for Elixir's built-in `:logger`. You configure it in your environment config (e.g., `config/prod.exs`).

```elixir
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
```

## Supported Adapters & Usage

`LogOut` provides four built-in adapters out of the box.

### Zulip (Highly Recommended for Multiple Projects)

Zulip is highly recommended because of its unique Stream/Topic threading model. Your `#alerts` stream won't become a completely unreadable wall of text if your database goes down, because individual project names are grouped by Topic.

```elixir
config :logger, LogOut,
  adapters: [
    {LogOut.Adapters.Zulip, 
      url: "https://zulip.example.com",
      bot_email: "bot@example.com", 
      bot_api_key: System.get_env("ZULIP_API_KEY"),
      stream: "alerts",
      # topic defaults to the global `project_name` if not specified
      topic: "my-app-production" 
    }
  ]
```

### Telegram (Recommended for Instant Mobile Push)

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

### Discord / Slack

Both use standard generic Incoming Webhook URLs for channels.

```elixir
config :logger, LogOut,
  adapters: [
    {LogOut.Adapters.Discord, url: System.get_env("DISCORD_WEBHOOK_URL")},
    {LogOut.Adapters.Slack, url: System.get_env("SLACK_WEBHOOK_URL")}
  ]
```

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
