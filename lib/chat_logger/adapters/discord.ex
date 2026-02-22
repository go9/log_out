defmodule ChatLogger.Adapters.Discord do
  @moduledoc """
  Adapter to send Elixir logs to a Discord Webhook.
  """
  @behaviour ChatLogger.Adapter

  @impl true
  def send_message(log_event, config) do
    url = Keyword.get(config, :url) || Keyword.get(config, :webhook_url)

    if url do
      msg = ChatLogger.format_message(log_event)
      level_emoji = ChatLogger.get_emoji(log_event.level)
      module_name = ChatLogger.format_mfa(log_event)
      project_name = Keyword.get(config, :project_name, "App")

      # Discord standard incoming webhook formatting
      # Discord limits messages to 2000 chars
      truncated_msg = String.slice(msg, 0..1800)

      payload = %{
        content: "#{level_emoji} **[#{project_name}] #{String.upcase(to_string(log_event.level))}**\n`#{module_name}`\n```elixir\n#{truncated_msg}\n```"
      }

      Req.post(url, json: payload)
    else
      :ok
    end
  end
end
