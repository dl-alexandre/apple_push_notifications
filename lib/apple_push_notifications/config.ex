defmodule ApplePushNotifications.Config do
  @moduledoc false

  @default_base_url "https://api.push.apple.com"
  @default_sandbox_url "https://api.sandbox.push.apple.com"
  @default_ttl 20 * 60

  defstruct [
    :team_id,
    :key_id,
    :bundle_id,
    :private_key,
    :private_key_path,
    :base_url,
    :sandbox,
    :token_ttl_seconds,
    :req_options,
    :pool_size
  ]

  @type t :: %__MODULE__{
          team_id: String.t() | nil,
          key_id: String.t() | nil,
          bundle_id: String.t() | nil,
          private_key: String.t() | nil,
          private_key_path: String.t() | nil,
          base_url: String.t(),
          sandbox: boolean(),
          token_ttl_seconds: pos_integer(),
          req_options: keyword(),
          pool_size: pos_integer()
        }

  @doc """
  Build a config struct by merging `Application.get_all_env/1` with per-call `opts`.
  Per-call options win.
  """
  @spec load(keyword()) :: t()
  def load(opts \\ []) do
    env = Application.get_all_env(:apple_push_notifications)
    merged = Keyword.merge(env, opts)

    sandbox = Keyword.get(merged, :sandbox, false)

    %__MODULE__{
      team_id: fetch(merged, :team_id),
      key_id: fetch(merged, :key_id),
      bundle_id: fetch(merged, :bundle_id),
      private_key: fetch(merged, :private_key),
      private_key_path: fetch(merged, :private_key_path),
      base_url:
        Keyword.get(
          merged,
          :base_url,
          if(sandbox, do: @default_sandbox_url, else: @default_base_url)
        ),
      sandbox: sandbox,
      token_ttl_seconds: Keyword.get(merged, :token_ttl_seconds, @default_ttl),
      req_options: Keyword.get(merged, :req_options, []),
      pool_size: Keyword.get(merged, :pool_size, 10)
    }
  end

  @doc "Return the PEM string, reading from `:private_key_path` if needed."
  @spec private_key_pem!(t()) :: String.t()
  def private_key_pem!(%__MODULE__{private_key: pem}) when is_binary(pem) and pem != "", do: pem

  def private_key_pem!(%__MODULE__{private_key_path: path}) when is_binary(path) and path != "" do
    File.read!(path)
  end

  def private_key_pem!(_), do: raise(ArgumentError, "missing :private_key or :private_key_path")

  defp fetch(kw, key) do
    case Keyword.get(kw, key) do
      "" -> nil
      value -> value
    end
  end
end
