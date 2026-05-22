defmodule LogOut do
  @moduledoc """
  An Elixir `:logger` backend that forwards application logs and exceptions to team chat platforms.

  `LogOut` intercepts standard Elixir `Logger` events across your application and dispatches them seamlessly to configured adapters like Slack or Telegram. Because it uses `Task.start/1` internally, slow HTTP requests to external webhooks will never block your application's executing processes or HTTP request handlers.

  ## Adapters

  See `LogOut.Adapter` for details on how to implement custom chat integrations, or use one of the built-in providers:
  - `LogOut.Adapters.Zulip`
  - `LogOut.Adapters.Slack`
  - `LogOut.Adapters.Discord`
  - `LogOut.Adapters.Telegram`
  """

  @behaviour :gen_event

  def init(__MODULE__) do
    {:ok, configure(%{})}
  end

  def handle_call({:configure, opts}, _state) do
    {:ok, :ok, configure(opts)}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    level = normalize_level(level)

    if forward?(level, state) do
      # Format message into an event shape the adapters expect
      log_event = %{
        level: level,
        msg: {:string, msg |> to_string()},
        meta: Map.new(md)
      }

      Enum.each(state.adapters, fn {adapter_module, adapter_config} ->
        merged_config = Keyword.merge(state.config, adapter_config)
        Task.start(fn -> adapter_module.send_message(log_event, merged_config) end)
      end)
    end

    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp configure(opts) do
    env_config = Application.get_env(:logger, LogOut, [])

    # opts from init might be a map or a keyword list, ensure it's a keyword list
    opts_kw = if is_map(opts), do: Map.to_list(opts), else: opts

    config = Keyword.merge(env_config, opts_kw)

    %{
      level: Keyword.get(config, :level, :warning),
      levels: config |> Keyword.get(:levels) |> normalize_levels(),
      adapters: Keyword.get(config, :adapters, []),
      config: config
    }
  end

  # When an explicit `levels` allowlist is configured, only those exact levels
  # are forwarded — this is how a caller forwards `:warning` WITHOUT `:error`
  # (a min-level threshold can't express that). Otherwise fall back to the
  # min-level threshold semantics.
  defp forward?(level, %{levels: levels}) when is_list(levels), do: level in levels
  defp forward?(level, %{level: configured}), do: meets_level?(level, configured)

  defp meets_level?(_event_level, nil), do: true
  defp meets_level?(event_level, configured_level) do
    Logger.compare_levels(event_level, normalize_level(configured_level)) != :lt
  end

  defp normalize_levels(nil), do: nil
  defp normalize_levels(levels) when is_list(levels), do: Enum.map(levels, &normalize_level/1)

  # The deprecated `:warn` alias still appears on events emitted by older
  # dependencies. Map it to `:warning` before it reaches `Logger.compare_levels/2`,
  # which would otherwise log its own deprecation warning on every event and
  # flood the configured adapters.
  defp normalize_level(:warn), do: :warning
  defp normalize_level(level), do: level

  @doc """
  Safely formats diverse Elixir log messages (strings, reports, format strings) into a flat string.
  """
  def format_message(%{msg: {:string, string}}), do: to_string(string)
  def format_message(%{msg: {:report, report}}), do: inspect(report, pretty: true)
  def format_message(%{msg: {format, args}}), do: :io_lib.format(format, args) |> to_string()
  def format_message(_), do: "Unknown log format"

  @doc """
  Extracts the `Module.function/arity` signature from the log event metadata if present.
  """
  def format_mfa(%{meta: %{mfa: {mod, fun, arity}}}), do: "#{inspect(mod)}.#{fun}/#{arity}"
  def format_mfa(%{meta: %{module: mod, function: fun}}), do: "#{inspect(mod)}.#{fun}"
  def format_mfa(%{meta: %{module: mod}}), do: "#{inspect(mod)}"
  def format_mfa(_), do: "Unknown Origin"

  @doc """
  Maps standard Elixir logger levels (e.g. `:warning`, `:error`) to standard emojis.
  """
  def get_emoji(:debug), do: "🐛"
  def get_emoji(:info), do: "ℹ️"
  def get_emoji(:notice), do: "📌"
  def get_emoji(:warning), do: "⚠️"
  def get_emoji(:error), do: "🔥"
  def get_emoji(:critical), do: "🚨"
  def get_emoji(:alert), do: "💥"
  def get_emoji(:emergency), do: "💀"
  def get_emoji(_), do: "📝"
end
