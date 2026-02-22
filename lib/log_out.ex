defmodule LogOut do
  @moduledoc """
  An Elixir Logger backend for chat applications.
  """

  @behaviour :gen_event

  def init(__MODULE__) do
    {:ok, configure(%{})}
  end

  def handle_call({:configure, opts}, _state) do
    {:ok, :ok, configure(opts)}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, state) do
    if meets_level?(level, state.level) do
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
      adapters: Keyword.get(config, :adapters, []),
      config: config
    }
  end

  defp meets_level?(_event_level, nil), do: true
  defp meets_level?(event_level, configured_level) do
    Logger.compare_levels(event_level, configured_level) != :lt
  end

  @doc """
  Helper to safely format the diverse Elixir log messages into a simple string.
  """
  def format_message(%{msg: {:string, string}}), do: to_string(string)
  def format_message(%{msg: {:report, report}}), do: inspect(report, pretty: true)
  def format_message(%{msg: {format, args}}), do: :io_lib.format(format, args) |> to_string()
  def format_message(_), do: "Unknown log format"

  @doc """
  Helper to extract the Module.function/arity from the log event metadata.
  """
  def format_mfa(%{meta: %{mfa: {mod, fun, arity}}}), do: "#{inspect(mod)}.#{fun}/#{arity}"
  def format_mfa(%{meta: %{module: mod, function: fun}}), do: "#{inspect(mod)}.#{fun}"
  def format_mfa(%{meta: %{module: mod}}), do: "#{inspect(mod)}"
  def format_mfa(_), do: "Unknown Origin"

  @doc """
  Helper to get standard emojis based on log level.
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
