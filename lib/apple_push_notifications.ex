defmodule ApplePushNotifications do
  @moduledoc """
  Elixir client for the [Apple Push Notification service (APNs)](https://developer.apple.com/documentation/usernotifications).

  Provides a complete interface for sending push notifications to iOS, macOS, watchOS, and tvOS devices.

  ## Features

  - HTTP/2 connection support (required by APNs)
  - JWT-based authentication with P8 keys
  - Connection pooling for high-throughput scenarios
  - Automatic token caching with expiration buffer
  - Rich notification support (images, actions, custom UI)
  - VoIP push support
  - Comprehensive error handling with device token validation

  ## Quick Start

      # Configure in config/config.exs
      config :apple_push_notifications,
        team_id: System.get_env("APNS_TEAM_ID"),
        key_id: System.get_env("APNS_KEY_ID"),
        bundle_id: System.get_env("APNS_BUNDLE_ID"),
        private_key: System.get_env("APNS_PRIVATE_KEY"),
        sandbox: true  # Set to false for production

      # Send a simple push notification
      ApplePushNotifications.push(
        "a1b2c3d4e5f6789...",
        alert: "Hello World!",
        badge: 1
      )

      # Send a rich notification with custom payload
      ApplePushNotifications.push(
        "a1b2c3d4e5f6789...",
        alert: %{title: "Breaking News", body: "Something happened!"},
        sound: "news_alert.caf",
        custom: %{article_id: "12345", category: "sports"}
      )

  ## Configuration

  Required configuration:
  - `team_id`: Your Apple Developer Team ID (10 characters)
  - `key_id`: Your APNs Auth Key ID (10 characters)
  - `bundle_id`: Your app's bundle identifier (e.g., "com.example.myapp")
  - `private_key`: The P8 private key content (or use `private_key_path`)
  - `sandbox`: `true` for development, `false` for production

  Optional configuration:
  - `base_url`: Override the APNs endpoint (default: api.push.apple.com or api.sandbox.push.apple.com)
  - `pool_size`: Connection pool size (default: 10)
  - `token_ttl_seconds`: JWT expiration time (default: 1200 seconds / 20 minutes)

  ## Per-Call Options

  Every function accepts per-call `opts` that override the application config:

      ApplePushNotifications.push(
        device_token,
        alert: "Hello",
        bundle_id: "com.example.differentapp"  # Override bundle_id for this call
      )

  ## Error Handling

  APNs returns specific error codes for different failure scenarios:

  - `BadDeviceToken`: Invalid or malformed device token
  - `Unregistered`: Device token is no longer valid (app uninstalled or token expired)
  - `PayloadTooLarge`: Notification payload exceeds 4KB (4096 bytes)
  - `TooManyRequests`: Rate limit exceeded
  - `InternalServerError`: APNs server error, retry later

  Use `ApplePushNotifications.Error.invalid_token?/1` to check if an error
  indicates the device token should be removed from your database.

  ## Background Notifications

  Send silent background notifications:

      ApplePushNotifications.background_push(
        device_token,
        content_available: true,
        custom: %{sync_data: true}
      )

  ## VoIP Push Notifications

  Send VoIP pushes for CallKit integration:

      ApplePushNotifications.voip_push(
        device_token,
        handle: "+1234567890",
        display_name: "Incoming Call"
      )

  ## Interruption Levels (iOS 15+)

  Control notification urgency:

      ApplePushNotifications.push(
        device_token,
        alert: "Important!",
        interruption_level: :time_sensitive,  # :passive, :active, :time_sensitive, :critical
        relevance_score: 0.75
      )

  """

  alias ApplePushNotifications.{Client, Token}

  @type opts :: keyword()
  @type response :: {:ok, map()} | {:error, term()}

  @doc """
  Return a cached APNs **access token** (after JWT generation).
  """
  @spec token(opts) :: {:ok, String.t()} | {:error, term()}
  def token(opts \\ []), do: Token.access_token(opts)

  @doc """
  Send a push notification to a device.

  ## Parameters

    - `device_token`: The 64-character hex device token
    - `opts`:
      - `alert`: String alert message or map with `title`/`body`/`subtitle`
      - `badge`: Integer badge count (nil to leave unchanged)
      - `sound`: Sound file name or "default"
      - `custom`: Map of custom payload data
      - `interruption_level`: One of `:passive`, `:active`, `:time_sensitive`, `:critical`
      - `relevance_score`: Float between 0 and 1 (iOS 15+)
      - Per-call config overrides (`team_id`, `key_id`, `bundle_id`, etc.)

  ## Examples

      # Simple text notification
      ApplePushNotifications.push(token, alert: "Hello!")

      # Rich notification with badge
      ApplePushNotifications.push(token,
        alert: %{title: "News", body: "New article available"},
        badge: 5,
        sound: "news.caf"
      )

      # With custom data
      ApplePushNotifications.push(token,
        alert: "Update available",
        custom: %{version: "2.0", force_update: false}
      )
  """
  @spec push(String.t(), opts) :: response
  def push(device_token, opts \\ []) when is_binary(device_token) do
    {notification_opts, config_opts} =
      Keyword.split(opts, [:alert, :badge, :sound, :custom, :interruption_level, :relevance_score])

    notification = build_notification(notification_opts)

    Client.push(device_token, notification, config_opts)
  end

  @doc """
  Send a silent background notification.

  Background notifications wake up the app to perform work without alerting the user.

  ## Parameters

    - `device_token`: The device token
    - `opts`:
      - `content_available`: Must be true (default)
      - `custom`: Custom data for background processing
      - Per-call config overrides

  ## Examples

      ApplePushNotifications.background_push(token,
        custom: %{fetch_new_data: true, endpoint: "/api/sync"}
      )
  """
  @spec background_push(String.t(), opts) :: response
  def background_push(device_token, opts \\ []) when is_binary(device_token) do
    {notification_opts, config_opts} = Keyword.split(opts, [:content_available, :custom])

    content_available = Keyword.get(notification_opts, :content_available, true)
    custom = Keyword.get(notification_opts, :custom, %{})

    notification = %{
      aps: %{
        content_available: if(content_available, do: 1, else: 0)
      }
    }

    # Merge custom payload
    notification = Map.merge(notification, custom)

    Client.push(device_token, notification, config_opts)
  end

  @doc """
  Send a VoIP push notification for CallKit.

  VoIP pushes use a different topic (bundle ID + ".voip").

  ## Parameters

    - `device_token`: The VoIP device token
    - `opts`:
      - `handle`: Phone number or handle for the call
      - `display_name`: Caller display name
      - `custom`: Additional CallKit data
      - Per-call config overrides (bundle_id will have ".voip" appended)

  ## Examples

      ApplePushNotifications.voip_push(token,
        handle: "+1-555-123-4567",
        display_name: "John Doe",
        custom: %{uuid: "...", session_id: "..."}
      )
  """
  @spec voip_push(String.t(), opts) :: response
  def voip_push(device_token, opts \\ []) when is_binary(device_token) do
    {notification_opts, config_opts} = Keyword.split(opts, [:handle, :display_name, :custom])

    handle = Keyword.get(notification_opts, :handle, "")
    display_name = Keyword.get(notification_opts, :display_name, "")
    custom = Keyword.get(notification_opts, :custom, %{})

    notification =
      Map.merge(
        %{
          handle: handle,
          displayName: display_name
        },
        custom
      )

    # VoIP pushes use the voip topic (bundle_id.voip)
    config_opts =
      Keyword.update(config_opts, :bundle_id, nil, fn bundle_id ->
        if bundle_id, do: bundle_id <> ".voip", else: nil
      end)

    Client.push(device_token, notification, config_opts)
  end

  @doc """
  Send a notification to multiple devices.

  Note: Unlike Firebase Cloud Messaging, APNs does not support multicast in a single
  request. This function iterates over device tokens and sends individual requests.

  ## Parameters

    - `device_tokens`: List of device tokens
    - `opts`: Same options as `push/2`

  ## Returns

    - `{:ok, results}`: Map of device_token to `:ok` or `{:error, reason}`
    - `{:error, reason}`: Configuration error before sending

  ## Examples

      ApplePushNotifications.push_many([token1, token2, token3],
        alert: "Broadcast message",
        badge: 1
      )
  """
  @spec push_many([String.t()], opts) :: {:ok, map()} | {:error, term()}
  def push_many(device_tokens, opts \\ []) when is_list(device_tokens) do
    # Build the notification payload once
    {notification_opts, config_opts} =
      Keyword.split(opts, [:alert, :badge, :sound, :custom, :interruption_level, :relevance_score])

    notification = build_notification(notification_opts)

    # Send to each device
    results =
      Enum.reduce(device_tokens, %{}, fn token, acc ->
        result =
          case Client.push(token, notification, config_opts) do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, reason}
          end

        Map.put(acc, token, result)
      end)

    {:ok, results}
  end

  @doc """
  Validate a device token format.

  Device tokens should be exactly 64 hexadecimal characters.

  ## Examples

      ApplePushNotifications.valid_token?("a1b2c3d4e5f6...")  # true/false
  """
  @spec valid_token?(String.t()) :: boolean()
  def valid_token?(token), do: Client.valid_token?(token)

  @doc """
  Check if an error indicates an invalid/unregistered device token.

  Returns `true` if the error is one of:
  - `BadDeviceToken`: Token format is invalid
  - `Unregistered`: Token is no longer valid (app uninstalled, token rotated)

  When this returns `true`, you should remove the device token from your database.

  ## Examples

      case ApplePushNotifications.push(token, alert: "Hello") do
        {:ok, _} -> :ok
        {:error, error} ->
          if ApplePushNotifications.invalid_token_error?(error) do
            # Remove token from database
            User.remove_device_token(user_id, token)
          end
      end
  """
  @spec invalid_token_error?(term()) :: boolean()
  def invalid_token_error?(%ApplePushNotifications.Error{} = error) do
    ApplePushNotifications.Error.invalid_token?(error)
  end

  def invalid_token_error?(_), do: false

  # Private helper to build the notification payload
  defp build_notification(opts) do
    aps = %{}

    # Handle alert (string or map)
    aps =
      case Keyword.get(opts, :alert) do
        nil -> aps
        alert when is_binary(alert) -> Map.put(aps, :alert, alert)
        alert when is_map(alert) -> Map.put(aps, :alert, alert)
      end

    # Handle badge
    aps =
      case Keyword.get(opts, :badge) do
        nil -> aps
        badge -> Map.put(aps, :badge, badge)
      end

    # Handle sound
    aps =
      case Keyword.get(opts, :sound) do
        nil -> aps
        sound -> Map.put(aps, :sound, sound)
      end

    # Handle interruption level (iOS 15+)
    aps =
      case Keyword.get(opts, :interruption_level) do
        nil -> aps
        level -> Map.put(aps, :"interruption-level", interruption_level_string(level))
      end

    # Handle relevance score (iOS 15+)
    aps =
      case Keyword.get(opts, :relevance_score) do
        nil -> aps
        score -> Map.put(aps, :"relevance-score", score)
      end

    # Build the full notification
    notification = %{aps: aps}

    # Merge custom payload
    case Keyword.get(opts, :custom) do
      nil -> notification
      custom -> Map.merge(notification, custom)
    end
  end

  defp interruption_level_string(:passive), do: "passive"
  defp interruption_level_string(:active), do: "active"
  defp interruption_level_string(:time_sensitive), do: "time-sensitive"
  defp interruption_level_string(:critical), do: "critical"
  defp interruption_level_string(level) when is_binary(level), do: level
  defp interruption_level_string(_), do: "active"
end
