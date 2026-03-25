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

    # Topic resolution priority:
    # 1. Logger metadata :zulip_topic (e.g., Logger.info("msg", zulip_topic: "errors"))
    # 2. Configured :topic option
    # 3. Project name from config
    # 4. Fallback to "App"
    topic =
      log_event.meta[:zulip_topic] ||
      Keyword.get(config, :topic) ||
      Keyword.get(config, :project_name, "App")

    if url && bot_email && bot_api_key do
      msg = LogOut.format_message(log_event)
      level_emoji = LogOut.get_emoji(log_event.level)
      module_name = LogOut.format_mfa(log_event)

      content = "#{level_emoji} **#{String.upcase(to_string(log_event.level))}** in `#{module_name}`\n```elixir\n#{msg}\n```"

      # Zulip requires basic auth and standard form encoded inputs
      case Req.post(
             "#{url}/api/v1/messages",
             auth: {:basic, bot_email, bot_api_key},
             form: [
               type: "stream",
               to: stream,
               topic: topic,
               content: content
             ]
           ) do
        {:ok, %{status: 200}} ->
          :ok

        {:ok, %{status: status, body: %{"code" => "STREAM_DOES_NOT_EXIST"}}} ->
          require Logger
          Logger.warning(
            "Zulip stream '#{stream}' does not exist. Please create it manually in Zulip settings.",
            skip_handlers: [LogOut]
          )
          :ok

        {:ok, %{status: status, body: body}} ->
          require Logger
          Logger.warning("Zulip post failed: #{status} - #{inspect(body)}", skip_handlers: [LogOut])
          :ok

        {:error, reason} ->
          require Logger
          Logger.warning("Zulip connection error: #{inspect(reason)}", skip_handlers: [LogOut])
          :ok
      end
    else
      :ok
    end
  end
end
