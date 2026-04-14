#!/usr/bin/env elixir

Mix.install([
  {:apple_push_notifications, path: "."},
  {:dotenv, "~> 3.0"}
])

Dotenv.load()

defmodule ApplePushNotificationsLiveTest do
  def run do
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("APNs LIVE TEST")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("")

    configure_from_env()

    {:ok, _} = Application.ensure_all_started(:apple_push_notifications)
    IO.puts("✅ APNs application started")
    IO.puts("")

    IO.puts("Configuration:")
    IO.puts("  Team ID: #{System.get_env("APNS_TEAM_ID") || "NOT SET"}")
    IO.puts("  Key ID: #{System.get_env("APNS_KEY_ID") || "NOT SET"}")
    IO.puts("  Bundle ID: #{System.get_env("APNS_BUNDLE_ID") || "NOT SET"}")
    IO.puts("  Sandbox: #{System.get_env("APNS_SANDBOX") || "false"}")
    IO.puts("  Key File: #{System.get_env("APNS_PRIVATE_KEY_PATH") || "NOT SET"}")
    IO.puts("")

    IO.puts("► Test 1: JWT Token Generation")
    IO.puts(String.duplicate("-", 50))

    case ApplePushNotifications.token() do
      {:ok, token} ->
        IO.puts("✅ Token generated successfully")
        IO.puts("   Length: #{String.length(token)} characters")
        IO.puts("   Preview: #{String.slice(token, 0, 50)}...")
        IO.puts("")
        maybe_send_push()

      {:error, reason} ->
        IO.puts("❌ Token generation failed")
        IO.puts("   Reason: #{inspect(reason)}")
    end

    IO.puts("")
    IO.puts("=" <> String.duplicate("=", 70))
    IO.puts("Test complete")
    IO.puts("=" <> String.duplicate("=", 70))
  end

  defp configure_from_env do
    Application.put_env(:apple_push_notifications, :team_id, System.get_env("APNS_TEAM_ID"))
    Application.put_env(:apple_push_notifications, :key_id, System.get_env("APNS_KEY_ID"))
    Application.put_env(:apple_push_notifications, :bundle_id, System.get_env("APNS_BUNDLE_ID"))

    Application.put_env(
      :apple_push_notifications,
      :private_key_path,
      System.get_env("APNS_PRIVATE_KEY_PATH")
    )

    Application.put_env(
      :apple_push_notifications,
      :sandbox,
      System.get_env("APNS_SANDBOX", "false") == "true"
    )
  end

  defp maybe_send_push do
    case System.get_env("APNS_TEST_DEVICE_TOKEN") do
      nil ->
        IO.puts("► Test 2: Real Push Send")
        IO.puts(String.duplicate("-", 50))
        IO.puts("⏭️  Skipped: set APNS_TEST_DEVICE_TOKEN in .env to send a real push")

      "" ->
        IO.puts("► Test 2: Real Push Send")
        IO.puts(String.duplicate("-", 50))
        IO.puts("⏭️  Skipped: set APNS_TEST_DEVICE_TOKEN in .env to send a real push")

      device_token ->
        IO.puts("► Test 2: Real Push Send")
        IO.puts(String.duplicate("-", 50))

        if ApplePushNotifications.Client.valid_token?(device_token) do
          title = System.get_env("APNS_TEST_ALERT_TITLE", "Test Notification")
          body = System.get_env("APNS_TEST_ALERT_BODY", "Hello from Elixir APNs!")

          case ApplePushNotifications.push(device_token,
                 alert: %{title: title, body: body},
                 sound: "default"
               ) do
            {:ok, _} ->
              IO.puts("✅ Push accepted by APNs")
              IO.puts("   Check the target device for delivery")

            {:error, %ApplePushNotifications.Error{} = error} ->
              IO.puts("❌ Push rejected by APNs")
              IO.puts("   Status: #{error.status}")
              IO.puts("   Message: #{error.message}")
              IO.puts("   Details: #{inspect(error.details)}")

            {:error, reason} ->
              IO.puts("❌ Push failed")
              IO.puts("   Reason: #{inspect(reason)}")
          end
        else
          IO.puts("❌ APNS_TEST_DEVICE_TOKEN is not a valid 64-char hex token")
        end
    end
  end
end

ApplePushNotificationsLiveTest.run()
