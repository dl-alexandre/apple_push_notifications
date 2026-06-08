defmodule ApplePushNotifications.ClientTest do
  @moduledoc """
  Tests for ApplePushNotifications.Client module using Bypass for HTTP mocking.
  """

  use ExUnit.Case, async: false

  alias ApplePushNotifications.Client

  setup do
    bypass = Bypass.open()
    private_key = ApplePushNotifications.TestKey.generate_private_key()

    # Configure the application env for the test
    original_env = Application.get_all_env(:apple_push_notifications)

    Application.put_all_env(
      apple_push_notifications: [
        team_id: "TEAMID1234",
        key_id: "KEYID56789",
        bundle_id: "com.example.test",
        private_key: private_key,
        base_url: "http://localhost:#{bypass.port}",
        sandbox: true,
        req_options: [
          connect_options: [
            protocols: [:http1],
            timeout: 30_000
          ]
        ]
      ]
    )

    # Clear the TokenCache before each test
    ApplePushNotifications.TokenCache.clear()

    on_exit(fn ->
      # Restore original env
      Application.put_all_env(apple_push_notifications: original_env)
    end)

    {:ok, %{bypass: bypass}}
  end

  describe "push/3" do
    test "successfully sends push notification", %{bypass: bypass} do
      device_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"

      Bypass.expect(bypass, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/3/device/#{device_token}"

        # Check authorization and topic headers
        headers = Enum.map(conn.req_headers, fn {k, _} -> k end)
        assert "authorization" in headers
        assert "apns-topic" in headers
        assert "content-type" in headers

        # Verify the topic is the bundle ID
        topic =
          conn.req_headers
          |> Enum.find_value(fn
            {"apns-topic", v} -> v
            _ -> nil
          end)

        assert topic == "com.example.test"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["aps"]["alert"] == "Hello World!"
        assert payload["aps"]["badge"] == 1

        Plug.Conn.resp(conn, 200, "")
      end)

      assert {:ok, _} =
               Client.push(
                 device_token,
                 %{aps: %{alert: "Hello World!", badge: 1}},
                 []
               )
    end

    test "handles BadDeviceToken error", %{bypass: bypass} do
      device_token = "invalid_token"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(
          conn,
          400,
          Jason.encode!(%{"reason" => "BadDeviceToken"})
        )
      end)

      assert {:error, %ApplePushNotifications.Error{status: 400} = error} =
               Client.push(
                 device_token,
                 %{aps: %{alert: "Test"}},
                 []
               )

      assert ApplePushNotifications.Error.invalid_token?(error)
    end

    test "handles Unregistered error (410)", %{bypass: bypass} do
      device_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(
          conn,
          410,
          Jason.encode!(%{
            "reason" => "Unregistered",
            "timestamp" => System.system_time(:second)
          })
        )
      end)

      assert {:error, %ApplePushNotifications.Error{status: 410} = error} =
               Client.push(
                 device_token,
                 %{aps: %{alert: "Test"}},
                 []
               )

      assert ApplePushNotifications.Error.invalid_token?(error)
    end

    test "handles PayloadTooLarge error (413)", %{bypass: bypass} do
      device_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
      # Create a large payload (> 4096 bytes)
      large_payload = %{aps: %{alert: String.duplicate("x", 5000)}}

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(
          conn,
          413,
          Jason.encode!(%{"reason" => "PayloadTooLarge"})
        )
      end)

      assert {:error, %ApplePushNotifications.Error{status: 413}} =
               Client.push(
                 device_token,
                 large_payload,
                 []
               )
    end

    test "handles TooManyRequests error (429)", %{bypass: bypass} do
      device_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(
          conn,
          429,
          Jason.encode!(%{"reason" => "TooManyRequests"})
        )
      end)

      assert {:error, %ApplePushNotifications.Error{status: 429}} =
               Client.push(
                 device_token,
                 %{aps: %{alert: "Test"}},
                 []
               )
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      device_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"

      assert {:error, {:transport_error, _}} =
               Client.push(
                 device_token,
                 %{aps: %{alert: "Test"}},
                 []
               )
    end

    test "uses override bundle_id in topic header", %{bypass: bypass} do
      device_token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"

      Bypass.expect(bypass, fn conn ->
        # Verify the topic is the overridden bundle ID
        topic =
          conn.req_headers
          |> Enum.find_value(fn
            {"apns-topic", v} -> v
            _ -> nil
          end)

        assert topic == "com.custom.bundle"

        Plug.Conn.resp(conn, 200, "")
      end)

      assert {:ok, _} =
               Client.push(
                 device_token,
                 %{aps: %{alert: "Hello!"}},
                 bundle_id: "com.custom.bundle"
               )
    end
  end

  describe "valid_token?/1" do
    test "returns true for valid 64-character hex token" do
      token = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
      assert Client.valid_token?(token)
    end

    test "returns false for invalid length" do
      assert not Client.valid_token?("short")
      assert not Client.valid_token?(String.duplicate("a", 65))
    end

    test "returns false for non-hex characters" do
      assert not Client.valid_token?("xyz123" |> String.pad_trailing(64, "0"))
    end
  end

  describe "get_token/1" do
    test "returns token for valid config" do
      assert {:ok, token} = Client.get_token([])
      assert is_binary(token)
    end

    test "returns error for invalid config" do
      assert {:error, _} =
               Client.get_token(
                 team_id: nil,
                 key_id: nil,
                 private_key: nil
               )
    end
  end
end
