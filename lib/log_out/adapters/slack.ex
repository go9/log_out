defmodule LogOut.Adapters.Slack do
  @moduledoc """
  Adapter to send Elixir logs to a generic Slack Incoming Webhook.
  """
  @behaviour LogOut.Adapter

  @impl true
  def send_message(log_event, config) do
    url = Keyword.get(config, :url) || Keyword.get(config, :webhook_url)

    if url do
      msg = LogOut.format_message(log_event)
      level_emoji = LogOut.get_emoji(log_event.level)
      module_name = LogOut.format_mfa(log_event)
      project_name = Keyword.get(config, :project_name, "App")

      # Slack standard incoming webhook formatting
      payload = %{
        text: "#{level_emoji} *[#{project_name}] #{String.upcase(to_string(log_event.level))}*\n`#{module_name}`\n```\n#{msg}\n```"
      }

      Req.post(url, json: payload)
    else
      :ok
    end
  end
end
