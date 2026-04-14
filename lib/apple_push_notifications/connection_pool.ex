defmodule ApplePushNotifications.ConnectionPool do
  @moduledoc """
  Connection pool for APNs HTTP/2 requests.

  APNs requires HTTP/2 connections. This GenServer maintains a pool
  of reusable HTTP/2 connections to the APNs servers for efficiency.
  """

  use GenServer

  alias ApplePushNotifications.Config

  @default_timeout 30_000

  defstruct [
    :base_url,
    :connections,
    :pool_size,
    :timeout
  ]

  @doc "Start the connection pool."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get a connection from the pool."
  @spec get_connection(keyword()) :: {:ok, Req.Request.t()} | {:error, term()}
  def get_connection(opts \\ []) do
    GenServer.call(__MODULE__, {:get_connection, opts})
  end

  @doc "Return a connection to the pool."
  @spec return_connection(Req.Request.t()) :: :ok
  def return_connection(conn) do
    GenServer.cast(__MODULE__, {:return_connection, conn})
  end

  @impl true
  def init(opts) do
    config = Config.load(opts)

    # Pre-create connections for the pool
    connections =
      Enum.map(1..config.pool_size, fn _ ->
        create_connection(config)
      end)

    state = %__MODULE__{
      base_url: config.base_url,
      connections: connections,
      pool_size: config.pool_size,
      timeout: @default_timeout
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_connection, opts}, _from, state) do
    config = Config.load(opts)

    # For now, create a fresh connection per request with the right base_url
    # In production, you'd implement proper connection pooling
    conn = create_connection(config)
    {:reply, {:ok, conn}, state}
  end

  @impl true
  def handle_cast({:return_connection, _conn}, state) do
    # In a real pool, return to available connections
    {:noreply, state}
  end

  defp create_connection(config) do
    Req.new(
      base_url: config.base_url,
      # HTTP/2 is required for APNs
      connect_options: [
        protocols: [:http2],
        timeout: 30_000
      ],
      # APNs specific settings
      headers: [
        {"accept", "application/json"}
      ]
    )
    |> Req.merge(config.req_options)
  end
end
