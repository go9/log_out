defmodule ChatLogger.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_logger,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :req]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.0"}
    ]
  end
end
