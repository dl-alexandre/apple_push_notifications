# ApplePushNotifications

Elixir client for the [Apple Push Notification service (APNs)](https://developer.apple.com/documentation/usernotifications).

It provides server-side push delivery with:

- JWT auth using APNs `.p8` keys
- HTTP/2 requests
- token caching
- standard alerts
- background pushes
- VoIP pushes
- multi-device fan-out helpers

## Installation

Add to your `mix.exs`:

```elixir
defp deps do
  [
    {:apple_push_notifications, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
config :apple_push_notifications,
  team_id: System.get_env("APNS_TEAM_ID"),
  key_id: System.get_env("APNS_KEY_ID"),
  bundle_id: System.get_env("APNS_BUNDLE_ID"),
  private_key_path: System.get_env("APNS_PRIVATE_KEY_PATH"),
  sandbox: true
```

Supported options:

- `team_id` - Apple Developer Team ID
- `key_id` - APNs key ID
- `bundle_id` - app bundle identifier used as the APNs topic
- `private_key` - inline `.p8` contents
- `private_key_path` - path to the `.p8` file
- `sandbox` - `true` for development, `false` for production
- `pool_size` - connection pool size
- `token_ttl_seconds` - defaults to the package setting

## Quick Start

```elixir
# Standard push
ApplePushNotifications.push(device_token,
  alert: %{title: "Hello", body: "World"},
  badge: 1,
  sound: "default"
)

# Background push
ApplePushNotifications.background_push(device_token,
  custom: %{refresh: true}
)

# VoIP push
ApplePushNotifications.voip_push(device_token,
  handle: "+15551234567",
  display_name: "Incoming Call"
)
```

## Multiple Devices

```elixir
{:ok, results} = ApplePushNotifications.push_many([token1, token2],
  alert: "Broadcast message"
)
```

## Live Testing

```bash
cd apple_push_notifications
source .env && elixir test_live.exs
```

To send a real push, set `APNS_TEST_DEVICE_TOKEN` in `.env`.

## Errors

APNs failures are wrapped in `ApplePushNotifications.Error`.

Common APNs reasons include:

- `BadDeviceToken`
- `Unregistered`
- `PayloadTooLarge`
- `TooManyRequests`

Use `ApplePushNotifications.Error.invalid_token?/1` to decide when a token should be removed from your database.

## License

MIT
