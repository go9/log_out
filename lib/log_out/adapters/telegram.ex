defmodule LogOut.Adapters.Telegram do
  @moduledoc """
  Adapter to send Elixir logs to a Telegram group or channel via a Bot.
  """
  @behaviour LogOut.Adapter

  @impl true
  def send_message(log_event, config) do
    bot_token = Keyword.get(config, :bot_token) || Keyword.get(config, :token)
    chat_id = Keyword.get(config, :chat_id)
    thread_id = Keyword.get(config, :message_thread_id)

    if bot_token && chat_id do
      msg = LogOut.format_message(log_event)
      level_emoji = LogOut.get_emoji(log_event.level)
      project_name = Keyword.get(config, :project_name, "App")

      # Clean msg for MarkdownV2 issues with special characters
      # or just use standard parsing. Telegram limits to 4096.
      safe_msg = String.slice(msg, 0..3900)

      text = "#{level_emoji} *[#{project_name}] #{String.upcase(to_string(log_event.level))}*\n```\n#{safe_msg}\n```"

      form_data =
        [
          chat_id: chat_id,
          text: text,
          parse_mode: "Markdown"
        ]

      # Add thread id if sending to a specific topic in a group
      form_data =
        if thread_id, do: Keyword.put(form_data, :message_thread_id, thread_id), else: form_data

      Req.post("https://api.telegram.org/bot#{bot_token}/sendMessage", form: form_data)
    else
      :ok
    end
  end
end
