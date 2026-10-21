defmodule Quiz.Storage.R2 do
  @moduledoc """
  Cloudflare R2 (S3-compatible) `Quiz.Storage` adapter for production.

  Dormant by default: it is only selected when R2 credentials are present in the
  environment (see `config/runtime.exs`). Until then the app uses
  `Quiz.Storage.Local` everywhere, so this module's `ex_aws` calls are never
  exercised.

  Expected config:

      config :quiz, Quiz.Storage.R2,
        bucket: "...",
        public_base_url: "https://cdn.example.com"

      config :ex_aws, :s3,
        access_key_id: "...",
        secret_access_key: "...",
        region: "auto",
        scheme: "https://",
        host: "<account-id>.r2.cloudflarestorage.com"
  """

  @behaviour Quiz.Storage

  alias Quiz.Accounts.Scope

  @impl true
  def put(%Scope{user: %{id: user_id}}, source_path, opts) do
    ext = opts |> Keyword.get(:filename) |> ext_of()
    key = Quiz.Storage.user_prefix(user_id) <> Ecto.UUID.generate() <> ext
    content_type = Keyword.get(opts, :content_type) || "application/octet-stream"

    with {:ok, body} <- File.read(source_path),
         {:ok, _} <-
           bucket()
           |> ExAws.S3.put_object(key, body, content_type: content_type)
           |> ExAws.request() do
      {:ok, key}
    end
  end

  @impl true
  def url(key), do: public_base_url() <> "/" <> key

  # Lists the prefix page by page (max 1000 keys each, which is also the limit
  # of one DeleteObjects call) and deletes each page before fetching the next.
  @impl true
  def delete_prefix(prefix), do: delete_page(prefix, nil)

  defp delete_page(prefix, continuation_token) do
    opts = if continuation_token, do: [continuation_token: continuation_token], else: []

    with {:ok, %{body: body}} <-
           bucket()
           |> ExAws.S3.list_objects_v2([prefix: prefix] ++ opts)
           |> ExAws.request(),
         :ok <- delete_keys(Enum.map(body.contents, & &1.key)) do
      case body do
        %{is_truncated: "true", next_continuation_token: next} when next != "" ->
          delete_page(prefix, next)

        _ ->
          :ok
      end
    end
  end

  defp delete_keys([]), do: :ok

  defp delete_keys(keys) do
    # In quiet mode the response only lists the keys that failed, and still
    # answers 200 — so a failed key has to be spotted in the body.
    case bucket() |> ExAws.S3.delete_multiple_objects(keys, quiet: true) |> ExAws.request() do
      {:ok, %{body: body}} ->
        if String.contains?(body, "<Error>"), do: {:error, {:delete_failed, body}}, else: :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp config, do: Application.fetch_env!(:quiz, __MODULE__)
  defp bucket, do: config()[:bucket]
  defp public_base_url, do: String.trim_trailing(config()[:public_base_url], "/")

  defp ext_of(nil), do: ""
  defp ext_of(name), do: name |> Path.extname() |> String.downcase()
end
