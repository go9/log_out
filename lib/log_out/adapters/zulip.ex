defmodule LogOut.Adapters.Zulip do
  @moduledoc """
  Adapter to send Elixir logs to a Zulip stream and topic.
  """
  @behaviour LogOut.Adapter

  @impl true
  def send_message(log_event, config) do
    url = Keyword.get(config, :url)
    bot_email = Keyword.get(config, :bot_email)
    bot_api_key = Keyword.get(config, :bot_api_key)

    stream = Keyword.get(config, :stream, "alerts")
    # Default Zulip topic name to the project name if not specified
    topic = Keyword.get(config, :topic) || Keyword.get(config, :project_name, "App")

    if url && bot_email && bot_api_key do
      msg = LogOut.format_message(log_event)
      level_emoji = LogOut.get_emoji(log_event.level)
      module_name = LogOut.format_mfa(log_event)

      content = "#{level_emoji} **#{String.upcase(to_string(log_event.level))}** in `#{module_name}`\n```elixir\n#{msg}\n```"

      # Zulip requires basic auth and standard form encoded inputs
      Req.post(
        "#{url}/api/v1/messages",
        auth: {:basic, bot_email, bot_api_key},
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
end
