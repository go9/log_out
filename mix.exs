defmodule LogOut.MixProject do
  use Mix.Project

  def project do
    [
      app: :log_out,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  defp description do
    "A pluggable Elixir Logger backend for routing exceptions and logs directly to team chat platforms like Slack, Discord, Telegram, and Zulip."
  end

  defp package do
    [
      name: "log_out",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/go9/log_out"}
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
      {:req, "~> 0.5.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
