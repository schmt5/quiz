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

  @spec adapter() :: module
  def adapter, do: Application.fetch_env!(:quiz, __MODULE__)[:adapter]

  @spec put(term, Path.t(), keyword) :: {:ok, String.t()} | {:error, term}
  def put(scope, source_path, opts \\ []), do: adapter().put(scope, source_path, opts)

  @spec url(String.t()) :: String.t()
  def url(key), do: adapter().url(key)
end
