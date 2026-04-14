defmodule ApplePushNotifications.TestKey do
  @moduledoc """
  Test helper for generating ES256 keys for testing.
  """

  @doc """
  Generates a new ES256 key pair and returns the private key in PEM format.
  """
  @spec generate_private_key() :: String.t()
  def generate_private_key do
    private_key = JOSE.JWK.generate_key({:ec, "P-256"})
    JOSE.JWK.to_pem(private_key) |> elem(1)
  end
end
