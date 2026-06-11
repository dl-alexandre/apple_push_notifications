defmodule ApplePushNotifications.TokenTest do
  @moduledoc """
  Tests for ApplePushNotifications.Token module.
  """

  use ExUnit.Case, async: true

  alias ApplePushNotifications.Token

  setup do
    private_key = ApplePushNotifications.TestKey.generate_private_key()

    opts = [
      team_id: "TEAMID1234",
      key_id: "KEYID56789",
      private_key: private_key
    ]

    {:ok, %{opts: opts}}
  end

  describe "generate_jwt/1" do
    test "returns a valid JWT token string", %{opts: opts} do
      assert {:ok, token} = Token.generate_jwt(opts)
      assert is_binary(token)
      assert String.split(token, ".") |> length() == 3
    end

    test "JWT contains correct header", %{opts: opts} do
      {:ok, token} = Token.generate_jwt(opts)
      [header_b64 | _] = String.split(token, ".")
      {:ok, header} = Base.url_decode64(header_b64, padding: false)
      header_json = Jason.decode!(header)

      assert header_json["alg"] == "ES256"
      assert header_json["kid"] == "KEYID56789"
      assert header_json["typ"] == "JWT"
    end

    test "JWT contains correct claims", %{opts: opts} do
      {:ok, token} = Token.generate_jwt(opts)
      [_, payload_b64 | _] = String.split(token, ".")
      {:ok, payload} = Base.url_decode64(payload_b64, padding: false)
      claims = Jason.decode!(payload)

      assert claims["iss"] == "TEAMID1234"
      assert is_integer(claims["iat"])
      assert is_integer(claims["exp"])
      assert claims["exp"] > claims["iat"]
      # Default TTL is 1200 seconds (20 minutes)
      assert claims["exp"] == claims["iat"] + 1200
    end

    test "respects custom token_ttl_seconds", %{opts: opts} do
      opts = Keyword.put(opts, :token_ttl_seconds, 3600)
      {:ok, token} = Token.generate_jwt(opts)
      [_, payload_b64 | _] = String.split(token, ".")
      {:ok, payload} = Base.url_decode64(payload_b64, padding: false)
      claims = Jason.decode!(payload)

      assert claims["exp"] == claims["iat"] + 3600
    end

    test "returns error for missing fields" do
      opts = [
        team_id: nil,
        key_id: nil,
        private_key: nil
      ]

      assert {:error, {:missing_config, _}} = Token.generate_jwt(opts)
    end

    test "returns an error tuple for malformed PEM", %{opts: opts} do
      assert {:error, {:token_generation_failed, message}} =
               Token.generate_jwt(Keyword.put(opts, :private_key, "not a pem"))

      assert is_binary(message)
    end
  end

  describe "access_token/1" do
    test "returns a valid JWT token", %{opts: opts} do
      {:ok, token} = Token.access_token(opts)
      assert is_binary(token)
      # Verify it's a valid JWT (has 3 parts)
      assert String.split(token, ".") |> length() == 3
    end
  end

  describe "access_token_with_expiry/1" do
    test "returns token with expiry timestamp", %{opts: opts} do
      assert {:ok, token, expires_at} = Token.access_token_with_expiry(opts)
      assert is_binary(token)
      assert is_integer(expires_at)

      now = System.system_time(:second)
      # Should be roughly 1200 seconds from now
      assert expires_at > now
      assert expires_at <= now + 1300
    end
  end
end
