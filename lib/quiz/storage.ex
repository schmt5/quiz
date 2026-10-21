defmodule Quiz.Storage do
  @moduledoc """
  Pluggable object storage for user-uploaded files (e.g. background images for
  `:pin_on_image` questions).

  The concrete backend is chosen by config:

      config :quiz, Quiz.Storage, adapter: Quiz.Storage.Local

  `put/3` persists a local temp file and returns an opaque **key**. The key (not
  a URL) is what callers store, which keeps persisted data portable across
  adapters. `url/1` resolves a key into a browser-loadable URL at render time.
  """

  @doc """
  Persists the file at `source_path` and returns `{:ok, key}`.

  `opts` may carry `:content_type` and `:filename` (used to derive an extension).
  """
  @callback put(scope :: term, source_path :: Path.t(), opts :: keyword) ::
              {:ok, String.t()} | {:error, term}

  @doc "Resolves a stored key into a browser-loadable URL."
  @callback url(key :: String.t()) :: String.t()

  @doc """
  Deletes every stored file whose key starts with `prefix`. Succeeds when
  nothing matches, so it is safe to retry.
  """
  @callback delete_prefix(prefix :: String.t()) :: :ok | {:error, term}

  @spec adapter() :: module
  def adapter, do: Application.fetch_env!(:quiz, __MODULE__)[:adapter]

  @spec put(term, Path.t(), keyword) :: {:ok, String.t()} | {:error, term}
  def put(scope, source_path, opts \\ []), do: adapter().put(scope, source_path, opts)

  @spec url(String.t()) :: String.t()
  def url(key), do: adapter().url(key)

  @doc """
  The key prefix under which all of a user's uploads live. Adapters build their
  keys from it, so `delete_prefix(user_prefix(id))` removes everything a user
  ever uploaded — including files no record points to any more.
  """
  @spec user_prefix(integer) :: String.t()
  def user_prefix(user_id) when is_integer(user_id), do: "uploads/#{user_id}/"

  @doc """
  Deletes every file under `prefix`.

  Only prefixes of the form `"uploads/<segment>/…/"` are accepted, so an empty
  or malformed prefix can never wipe the whole bucket.
  """
  @spec delete_prefix(String.t()) :: :ok | {:error, term}
  def delete_prefix("uploads/" <> rest = prefix) do
    if String.ends_with?(rest, "/") and String.trim(rest, "/") != "" and
         not String.contains?(rest, "..") do
      adapter().delete_prefix(prefix)
    else
      {:error, :invalid_prefix}
    end
  end

  def delete_prefix(_prefix), do: {:error, :invalid_prefix}
end
