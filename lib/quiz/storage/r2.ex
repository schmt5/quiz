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
    key = "uploads/#{user_id}/#{Ecto.UUID.generate()}#{ext}"
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

  defp config, do: Application.fetch_env!(:quiz, __MODULE__)
  defp bucket, do: config()[:bucket]
  defp public_base_url, do: String.trim_trailing(config()[:public_base_url], "/")

  defp ext_of(nil), do: ""
  defp ext_of(name), do: name |> Path.extname() |> String.downcase()
end
