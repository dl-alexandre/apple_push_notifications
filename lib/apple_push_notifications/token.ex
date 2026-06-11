defmodule ApplePushNotifications.Token do
  @moduledoc """
  APNs JWT token generation.

  APNs uses a P8 private key (ES256 P-256) to authenticate HTTP/2 requests.
  The JWT contains:
  - `iss`: Team ID (Apple Developer Team ID)
  - `iat`: Issued at timestamp
  - `kid`: Key ID from the APNs Auth Key

  This JWT is used directly as the Bearer token in API requests.
  """

  alias ApplePushNotifications.Config

  @type jwt :: String.t()

  @doc "Build and sign the APNs JWT (ES256)."
  @spec generate_jwt(keyword()) :: {:ok, jwt} | {:error, term()}
  def generate_jwt(opts \\ []) do
    config = Config.load(opts)
    now = System.system_time(:second)

    with {:ok, team_id} <- require_field(config.team_id, :team_id),
         {:ok, key_id} <- require_field(config.key_id, :key_id) do
      claims = %{
        "iss" => team_id,
        "iat" => now,
        "exp" => now + config.token_ttl_seconds
      }

      header = %{
        "alg" => "ES256",
        "kid" => key_id,
        "typ" => "JWT"
      }

      try do
        jwk = Config.private_key_pem!(config) |> JOSE.JWK.from_pem()
        {_, compact} = JOSE.JWT.sign(jwk, header, claims) |> JOSE.JWS.compact()
        {:ok, compact}
      rescue
        e in [ArgumentError, MatchError, ErlangError, File.Error] ->
          {:error, {:token_generation_failed, Exception.message(e)}}
      end
    end
  end

  @doc "Generate the APNs access token."
  @spec access_token(keyword()) :: {:ok, String.t()} | {:error, term()}
  def access_token(opts \\ []) do
    # APNs uses the JWT directly as the token
    generate_jwt(opts)
  end

  @doc """
  Like `access_token/1` but also returns the unix-epoch expiry time, for cache use.
  """
  @spec access_token_with_expiry(keyword()) ::
          {:ok, String.t(), integer()} | {:error, term()}
  def access_token_with_expiry(opts \\ []) do
    config = Config.load(opts)

    with {:ok, token} <- generate_jwt(opts) do
      expires_at = System.system_time(:second) + config.token_ttl_seconds
      {:ok, token, expires_at}
    end
  end

  defp require_field(nil, name), do: {:error, {:missing_config, name}}
  defp require_field("", name), do: {:error, {:missing_config, name}}
  defp require_field(value, _), do: {:ok, value}
end
