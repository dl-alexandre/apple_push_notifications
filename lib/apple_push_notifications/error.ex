defmodule ApplePushNotifications.Error do
  @moduledoc """
  Structured exception for APNs API failures.
  """

  defexception [:message, :status, :details]

  @type t :: %__MODULE__{
          message: String.t(),
          status: integer() | nil,
          details: map() | nil
        }

  @doc "Create an error from an HTTP response."
  @spec from_http(integer(), map() | binary() | nil) :: t()
  def from_http(status, body) when is_binary(body) and body != "" do
    # Try to parse JSON body
    details =
      case Jason.decode(body) do
        {:ok, decoded} when is_map(decoded) -> decoded
        _ -> %{"raw" => body}
      end

    from_http(status, details)
  end

  def from_http(status, body) when is_map(body) do
    %__MODULE__{
      message: body["reason"] || apns_reason(status),
      status: status,
      details: body
    }
  end

  def from_http(status, _) do
    %__MODULE__{
      message: apns_reason(status),
      status: status,
      details: nil
    }
  end

  @doc "Check if the error indicates an invalid device token."
  @spec invalid_token?(t()) :: boolean()
  def invalid_token?(%__MODULE__{details: %{"reason" => reason}}) do
    reason in ["BadDeviceToken", "Unregistered"]
  end

  def invalid_token?(_), do: false

  @doc "Get the error reason code from an APNs error response."
  @spec reason_code(t()) :: String.t() | nil
  def reason_code(%__MODULE__{details: %{"reason" => reason}}), do: reason
  def reason_code(%__MODULE__{message: message}), do: message
  def reason_code(_), do: nil

  # APNs specific HTTP status code meanings
  defp apns_reason(200), do: "Success"
  defp apns_reason(400), do: "Bad request"
  defp apns_reason(403), do: "Certificate or authentication error"
  defp apns_reason(405), do: "Invalid request method"
  defp apns_reason(410), do: "Device token unregistered"
  defp apns_reason(413), do: "Payload too large"
  defp apns_reason(429), do: "Too many requests"
  defp apns_reason(500), do: "Internal server error"
  defp apns_reason(503), do: "Service unavailable"
  defp apns_reason(status), do: "HTTP #{status}"
end
