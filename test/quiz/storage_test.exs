defmodule Quiz.StorageTest do
  # The local adapter's directory is shared config.
  use ExUnit.Case, async: false

  alias Quiz.Accounts.{Scope, User}
  alias Quiz.Storage

  setup do
    source =
      Path.join(System.tmp_dir!(), "storage_test_#{System.unique_integer([:positive])}.png")

    File.write!(source, "png")
    on_exit(fn -> File.rm(source) end)

    %{source: source}
  end

  defp scope(user_id), do: %Scope{user: %User{id: user_id}}

  defp stored?(key) do
    dir = Application.fetch_env!(:quiz, Quiz.Storage.Local)[:dir]
    File.exists?(Path.join(dir, Path.relative_to(key, "uploads")))
  end

  describe "user_prefix/1" do
    test "is the prefix every upload of that user is stored under", %{source: source} do
      user_id = System.unique_integer([:positive])

      {:ok, key} = Storage.put(scope(user_id), source, filename: "bild.png")

      assert String.starts_with?(key, Storage.user_prefix(user_id))
    end
  end

  describe "delete_prefix/1 (local adapter)" do
    test "removes all uploads of one user and leaves others alone", %{source: source} do
      user_id = System.unique_integer([:positive])
      other_id = System.unique_integer([:positive])

      {:ok, a} = Storage.put(scope(user_id), source, filename: "a.png")
      {:ok, b} = Storage.put(scope(user_id), source, filename: "b.png")
      {:ok, other} = Storage.put(scope(other_id), source, filename: "c.png")

      assert :ok = Storage.delete_prefix(Storage.user_prefix(user_id))

      refute stored?(a)
      refute stored?(b)
      assert stored?(other)
    end

    test "succeeds when nothing is stored under the prefix" do
      assert :ok = Storage.delete_prefix(Storage.user_prefix(System.unique_integer([:positive])))
    end

    test "rejects prefixes that could reach beyond a single user's uploads" do
      for prefix <- [
            "",
            "/",
            "uploads",
            "uploads/",
            "uploads//",
            "uploads/1",
            "other/1/",
            "uploads/../"
          ] do
        assert {:error, :invalid_prefix} = Storage.delete_prefix(prefix),
               "accepted #{inspect(prefix)}"
      end
    end
  end
end
