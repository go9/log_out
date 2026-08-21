defmodule LogOut.Adapters.Zulip do
  @moduledoc """
  Adapter to send Elixir logs to a Zulip stream and topic.

  ## Dynamic topics via `Logger` metadata

  The topic is normally fixed by config (`:topic`, falling back to
  `:project_name`), but a call site can route to a different topic by
  passing `zulip_topic:` metadata:

      Logger.warning("Order oversold", zulip_topic: "Oversell")

  This works with **no extra Logger configuration** — custom metadata keys
  passed at the call site reach every configured backend (including this
  one) unfiltered; the `:metadata` backend option only controls what
  `Logger.Backends.Console` prints, not what a custom `@behaviour
  LogOut.Adapter` module receives in `log_event.meta`. (Verified against a
  real `Logger.add_backend/1` + `config :logger, backends: [...]` boot path,
  not just a hand-built log event.)

  A `zulip_topic` value is only honoured when it is a non-empty binary:

    * Longer than Zulip's 60-character topic limit → truncated, not rejected.
    * Missing, blank, or not a binary (e.g. an atom or number) → falls back
      to the configured `:topic` / `:project_name` chain, exactly as if no
      metadata had been given. A malformed topic must never drop the alert.
  """
  @behaviour LogOut.Adapter

  @max_topic_length 60

  @impl true
  def send_message(log_event, config) do
    url = Keyword.get(config, :url)
    bot_email = Keyword.get(config, :bot_email)
    bot_api_key = Keyword.get(config, :bot_api_key)

    stream = Keyword.get(config, :stream, "alerts")
    topic = resolve_topic(log_event, config)

    if url && bot_email && bot_api_key do
      msg = LogOut.format_message(log_event)
      level_emoji = LogOut.get_emoji(log_event.level)
      module_name = LogOut.format_mfa(log_event)

      content =
        "#{level_emoji} **#{String.upcase(to_string(log_event.level))}** in `#{module_name}`\n```elixir\n#{msg}\n```"

      # Zulip requires basic auth and standard form encoded inputs
      # Format: {:basic, "username:password"} for Req 0.5.x
      Req.post(
        "#{url}/api/v1/messages",
        auth: {:basic, "#{bot_email}:#{bot_api_key}"},
        form: [
          type: "stream",
          to: stream,
          topic: topic,
          content: content
        ]
      )
    else
      :ok
    end
  end

  @doc false
  # Per-event `zulip_topic:` metadata takes priority over the static config
  # chain, but only when it's a topic Zulip could plausibly accept — a
  # malformed value must fall back rather than drop the message.
  # Public (but undocumented) so it's directly unit-testable without
  # standing up a fake Zulip server.
  def resolve_topic(log_event, config) do
    with meta when is_map(meta) <- Map.get(log_event, :meta, %{}),
         topic when is_binary(topic) and topic != "" <- Map.get(meta, :zulip_topic) do
      truncate_topic(topic)
    else
      _ -> default_topic(config)
    end
  end

  # Default Zulip topic name to the project name if not specified
  defp default_topic(config) do
    Keyword.get(config, :topic) || Keyword.get(config, :project_name, "App")
  end

  defp truncate_topic(topic) do
    if String.length(topic) > @max_topic_length do
      String.slice(topic, 0, @max_topic_length)
    else
      topic
    end
  end
end
