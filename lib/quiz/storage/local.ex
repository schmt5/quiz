defmodule Quiz.Storage.Local do
  @moduledoc """
  Local-disk `Quiz.Storage` adapter for dev and test.

  Files are written under the configured `:dir` and served by the
  `Plug.Static` mounted at `/uploads` in `QuizWeb.Endpoint`.

      config :quiz, Quiz.Storage.Local, dir: Path.join(["priv", "static", "uploads"])
  """

  @behaviour Quiz.Storage

  alias Quiz.Accounts.Scope

  @impl true
  def put(%Scope{user: %{id: user_id}}, source_path, opts) do
    ext = extension(opts, source_path)
    key = "uploads/#{user_id}/#{Ecto.UUID.generate()}#{ext}"
    dest = Path.join(dir(), Path.relative_to(key, "uploads"))

    with :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.cp(source_path, dest) do
      {:ok, key}
    end
  end

  @impl true
  def url(key), do: "/" <> key

  defp dir, do: Application.fetch_env!(:quiz, __MODULE__)[:dir]

  defp extension(opts, source_path) do
    from_name = opts |> Keyword.get(:filename) |> ext_of()
    if from_name != "", do: from_name, else: ext_of(source_path)
  end

  defp ext_of(nil), do: ""
  defp ext_of(name), do: name |> Path.extname() |> String.downcase()
end
