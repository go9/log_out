defmodule LogOut.Adapter do
  @moduledoc """
  A behaviour module for implementing custom chat log adapters.
  """

  @doc """
  Should handle mapping the Elixir log_event and the given adapter config
  into an HTTP request to the target chat service.
  """
  @callback send_message(log_event :: map(), config :: keyword()) :: any()
end
