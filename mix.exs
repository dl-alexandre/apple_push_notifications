defmodule ApplePushNotifications.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dl-alexandre/apple_push_notifications"

  def project do
    [
      app: :apple_push_notifications,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :public_key],
      mod: {ApplePushNotifications.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:jose, "~> 1.11"},
      {:bypass, "~> 2.1", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Elixir client for Apple Push Notification service (APNs)."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "v#{@version}",
      groups_for_modules: [
        Auth: [
          ApplePushNotifications.Config,
          ApplePushNotifications.Token,
          ApplePushNotifications.TokenCache
        ],
        HTTP: [ApplePushNotifications.Client, ApplePushNotifications.ConnectionPool],
        API: [ApplePushNotifications],
        Errors: [ApplePushNotifications.Error]
      ]
    ]
  end
end
