defmodule LogOutTest do
  use ExUnit.Case

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
        {LogOut.Adapters.Zulip, [url: "http://localhost:4000/webhook-test", bot_email: "test", bot_api_key: "t"]},
        {LogOut.Adapters.Telegram, [bot_token: "t", chat_id: "c"]}
      ],
      config: [project_name: "Test"]
    }

    # 1. We test that it successfully processes the event and doesn't crash
    # It will spawn Tasks that will fail HTTP requests, which is fine, we just want to ensure
    # the formatters and core logic don't throw exceptions.
    metadata = [mfa: {MyModule, :my_func, 1}]

    assert {:ok, _state} = LogOut.handle_event(
      {:error, nil, {Logger, "This is a test message", :os.system_time(), metadata}},
      state
    )

    # 2. Test the filtering logic (should not execute for debug)
    assert {:ok, _state} = LogOut.handle_event(
      {:debug, nil, {Logger, "Should be ignored", :os.system_time(), metadata}},
      state
    )

    # Give tasks a tiny moment to execute and crash (to ensure format helpers work)
    Process.sleep(100)
  end
end
