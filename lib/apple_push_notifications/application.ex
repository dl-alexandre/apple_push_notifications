defmodule ApplePushNotifications.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ApplePushNotifications.TokenCache, []}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: ApplePushNotifications.Supervisor
    )
  end
end
