defmodule LogOutTest.EchoAdapter do
  @moduledoc false
  # Test adapter: instead of an HTTP call, report the forwarded level back to
  # the test process so filtering can be asserted with assert_receive.
  def send_message(event, config), do: send(config[:test_pid], {:forwarded, event.level})
end

defmodule LogOutTest.EchoZulipTopicAdapter do
  @moduledoc false
  # Test adapter: resolves the topic exactly like the real Zulip adapter would,
  # then reports it back to the test process — used to prove `zulip_topic:`
  # metadata survives the full LogOut.handle_event/2 path (not just a
  # hand-built log_event), which is the actual regression this guards.
  def send_message(event, config) do
    send(config[:test_pid], {:resolved_topic, LogOut.Adapters.Zulip.resolve_topic(event, config)})
  end
end

defmodule LogOutTest do
  use ExUnit.Case

  alias LogOutTest.EchoAdapter

  test "logger can be configured and handles basic log event" do
    # Ensure finch and req apps are actually running in the test environment
    Application.ensure_all_started(:finch)
    Application.ensure_all_started(:req)

    # Send a log directly instead of relying on the global logger to boot synchronously
    state = %{
      level: :info,
      adapters: [
        {LogOut.Adapters.Slack, [url: "http://localhost:4000/webhook-test"]},
        {LogOut.Adapters.Discord, [url: "http://localhost:4000/webhook-test"]},
        {LogOut.Adapters.Zulip,
         [url: "http://localhost:4000/webhook-test", bot_email: "test", bot_api_key: "t"]},
        {LogOut.Adapters.Telegram, [bot_token: "t", chat_id: "c"]}
      ],
      config: [project_name: "Test"]
    }

    # 1. We test that it successfully processes the event and doesn't crash
    # It will spawn Tasks that will fail HTTP requests, which is fine, we just want to ensure
    # the formatters and core logic don't throw exceptions.
    metadata = [mfa: {MyModule, :my_func, 1}]

    assert {:ok, _state} =
             LogOut.handle_event(
               {:error, nil, {Logger, "This is a test message", :os.system_time(), metadata}},
               state
             )

    # 2. Test the filtering logic (should not execute for debug)
    assert {:ok, _state} =
             LogOut.handle_event(
               {:debug, nil, {Logger, "Should be ignored", :os.system_time(), metadata}},
               state
             )

    # Give tasks a tiny moment to execute and crash (to ensure format helpers work)
    Process.sleep(100)
  end

  describe "level filtering" do
    defp echo_state(filter) do
      Map.merge(%{adapters: [{EchoAdapter, [test_pid: self()]}], config: []}, filter)
    end

    test "min-level threshold forwards the level and everything above it" do
      state = echo_state(%{level: :warning})

      LogOut.handle_event(log(:warning), state)
      LogOut.handle_event(log(:error), state)
      LogOut.handle_event(log(:info), state)

      assert_receive {:forwarded, :warning}
      assert_receive {:forwarded, :error}
      refute_receive {:forwarded, :info}
    end

    test "levels allowlist forwards only the listed levels (warning WITHOUT error)" do
      state = echo_state(%{level: :warning, levels: [:warning, :notice]})

      LogOut.handle_event(log(:warning), state)
      LogOut.handle_event(log(:error), state)
      LogOut.handle_event(log(:info), state)

      assert_receive {:forwarded, :warning}
      refute_receive {:forwarded, :error}
      refute_receive {:forwarded, :info}
    end

    test "deprecated :warn alias is normalized to :warning and forwarded under the allowlist" do
      state = echo_state(%{levels: [:warning]})

      LogOut.handle_event(log(:warn), state)

      assert_receive {:forwarded, :warning}
    end

    defp log(level) do
      {level, nil, {Logger, "msg", :os.system_time(), [mfa: {M, :f, 1}]}}
    end
  end

  describe "Zulip adapter topic resolution" do
    alias LogOut.Adapters.Zulip

    defp event(meta), do: %{level: :warning, msg: {:string, "msg"}, meta: meta}

    test "metadata present: zulip_topic wins over the config chain" do
      config = [topic: "configured-topic", project_name: "App"]

      assert Zulip.resolve_topic(event(%{zulip_topic: "Oversell"}), config) == "Oversell"
    end

    test "metadata absent: falls back to configured :topic (existing behaviour unchanged)" do
      config = [topic: "configured-topic", project_name: "App"]

      assert Zulip.resolve_topic(event(%{}), config) == "configured-topic"
    end

    test "metadata absent and no :topic: falls back to :project_name" do
      config = [project_name: "MyApp"]

      assert Zulip.resolve_topic(event(%{}), config) == "MyApp"
    end

    test "metadata absent, no :topic, no :project_name: falls back to \"App\"" do
      assert Zulip.resolve_topic(event(%{}), []) == "App"
    end

    test "overlong topic is truncated to Zulip's 60-character limit, not rejected" do
      overlong = String.duplicate("x", 90)
      config = [topic: "configured-topic"]

      resolved = Zulip.resolve_topic(event(%{zulip_topic: overlong}), config)

      assert resolved == String.duplicate("x", 60)
      assert String.length(resolved) == 60
    end

    test "non-binary topic falls back to the configured default rather than dropping the message" do
      config = [topic: "configured-topic"]

      assert Zulip.resolve_topic(event(%{zulip_topic: :oversell}), config) == "configured-topic"
      assert Zulip.resolve_topic(event(%{zulip_topic: 123}), config) == "configured-topic"
    end

    test "blank topic falls back to the configured default rather than posting an empty topic" do
      config = [topic: "configured-topic"]

      assert Zulip.resolve_topic(event(%{zulip_topic: ""}), config) == "configured-topic"
    end

    test "zulip_topic metadata survives the real LogOut.handle_event/2 path unfiltered" do
      # Regression guard for the actual trap this ticket called out: Logger
      # call-site metadata must reach log_event.meta through handle_event's
      # own Map.new(md) construction, not just when a test hand-builds the
      # log_event map directly.
      state = %{
        level: :warning,
        adapters: [
          {LogOutTest.EchoZulipTopicAdapter, [test_pid: self(), topic: "configured-topic"]}
        ],
        config: []
      }

      raw_event =
        {:warning, nil, {Logger, "Order oversold", :os.system_time(), [zulip_topic: "Oversell"]}}

      assert {:ok, _state} = LogOut.handle_event(raw_event, state)

      assert_receive {:resolved_topic, "Oversell"}
    end
  end
end
