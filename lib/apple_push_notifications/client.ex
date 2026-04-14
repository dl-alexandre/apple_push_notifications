defmodule ApplePushNotifications.Client do
  @moduledoc """
  HTTP/2 client for APNs API.

  APNs requires HTTP/2 connections. This client handles:
  - Token-based authentication (JWT in Authorization header)
  - HTTP/2 protocol negotiation
  - APNs-specific error handling
  """

  alias ApplePushNotifications.{Config, Error, Token, TokenCache}

  @config_keys [
    :team_id,
    :key_id,
    :bundle_id,
    :private_key,
    :private_key_path,
    :base_url,
    :sandbox,
    :token_ttl_seconds,
    :req_options
  ]

  @doc """
  Send a push notification to a device.

  ## Parameters

    - `device_token`: The hex-encoded device token (64 characters)
    - `notification`: Map containing:
      - `aps`: Alert dictionary with `alert`, `badge`, `sound`, etc.
      - Custom payload keys
    - `opts`: Per-call configuration overrides

  ## Examples

      ApplePushNotifications.Client.push(
        "a1b2c3d4e5f6...",
        %{
          aps: %{
            alert: %{title: "Hello", body: "World"},
            badge: 1,
            sound: "default"
          }
        }
      )
  """
  @spec push(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def push(device_token, notification, opts \\ []) do
    {config_opts, _meta, _params} = split_opts(opts)
    config = Config.load(config_opts)

    with {:ok, access_token} <- fetch_access_token(config_opts),
         {:ok, bundle_id} <- validate_bundle_id(config.bundle_id) do
      req =
        Req.new(
          base_url: config.base_url,
          # HTTP/2 is required for APNs
          connect_options: [
            protocols: [:http2],
            timeout: 30_000
          ],
          headers: [
            {"authorization", "Bearer #{access_token}"},
            {"apns-topic", bundle_id},
            {"content-type", "application/json"}
          ]
        )
        |> Req.merge(config.req_options)

      path = "/3/device/#{device_token}"

      req
      |> Req.post(url: path, json: notification)
      |> normalize()
    end
  end

  @doc """
  Send a push notification using the cached token.

  This is the preferred method for production use as it uses
  the TokenCache to avoid regenerating JWTs on every request.
  """
  @spec push_cached(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def push_cached(device_token, notification) do
    push(device_token, notification, [])
  end

  @doc """
  Validate a device token format.

  Device tokens should be 64 hex characters.
  """
  @spec valid_token?(String.t()) :: boolean()
  def valid_token?(token) when is_binary(token) do
    String.length(token) == 64 && token =~ ~r/^[a-fA-F0-9]+$/
  end

  def valid_token?(_), do: false

  @doc """
  Get an access token for use in manual requests.
  """
  @spec get_token(keyword()) :: {:ok, String.t()} | {:error, term()}
  def get_token(opts \\ []) do
    {config_opts, _, _} = split_opts(opts)
    fetch_access_token(config_opts)
  end

  defp fetch_access_token([]), do: TokenCache.fetch()
  defp fetch_access_token(config_opts), do: Token.access_token(config_opts)

  defp validate_bundle_id(nil), do: {:error, {:missing_config, :bundle_id}}
  defp validate_bundle_id(""), do: {:error, {:missing_config, :bundle_id}}
  defp validate_bundle_id(bundle_id), do: {:ok, bundle_id}

  defp split_opts(opts) do
    {config, rest} = Keyword.split(opts, @config_keys)
    {meta, params} = Keyword.split(rest, [])
    {config, meta, params}
  end

  defp normalize({:ok, %Req.Response{status: 200, body: body}}) do
    # APNs returns empty body on success
    {:ok, body || %{}}
  end

  defp normalize({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body || %{}}
  end

  defp normalize({:ok, %Req.Response{status: status, body: body}}) do
    {:error, Error.from_http(status, body)}
  end

  defp normalize({:error, reason}) do
    {:error, {:transport_error, reason}}
  end
end
