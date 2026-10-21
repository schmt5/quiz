defmodule Quiz.Storage.R2Test do
  # Swaps global :ex_aws / :quiz config for the duration of each test.
  use ExUnit.Case, async: false

  alias Quiz.Storage.R2

  @env [
    {:quiz, R2, bucket: "quiz-test", public_base_url: "https://cdn.example.com"},
    {:ex_aws, :access_key_id, "test-key"},
    {:ex_aws, :secret_access_key, "test-secret"},
    {:ex_aws, :req_opts, plug: {Req.Test, R2}}
  ]

  setup do
    previous =
      for {app, key, value} <- @env do
        old = Application.fetch_env(app, key)
        Application.put_env(app, key, value)
        {app, key, old}
      end

    on_exit(fn ->
      for {app, key, old} <- previous do
        case old do
          {:ok, value} -> Application.put_env(app, key, value)
          :error -> Application.delete_env(app, key)
        end
      end
    end)

    :ok
  end

  # Serves `pages` (lists of keys) as consecutive ListObjectsV2 pages and
  # reports every DeleteObjects body to the test process.
  defp stub_bucket(pages, delete_response \\ "<DeleteResult></DeleteResult>") do
    test = self()

    Req.Test.stub(R2, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case {conn.method, conn.query_params} do
        {"GET", params} ->
          send(test, {:listed, params})
          page = page_index(params["continuation-token"])
          keys = Enum.at(pages, page, [])
          last? = page >= length(pages) - 1
          Plug.Conn.send_resp(conn, 200, list_xml(keys, last?, "page-#{page + 1}"))

        {"POST", %{"delete" => _}} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          send(test, {:deleted, Regex.scan(~r{<Key>(.*?)</Key>}, body, capture: :all_but_first)})
          Plug.Conn.send_resp(conn, 200, delete_response)
      end
    end)
  end

  defp page_index(nil), do: 0
  defp page_index("page-" <> n), do: String.to_integer(n)

  defp list_xml(keys, last?, next_token) do
    contents = Enum.map_join(keys, &"<Contents><Key>#{&1}</Key></Contents>")
    token = if last?, do: "", else: "<NextContinuationToken>#{next_token}</NextContinuationToken>"

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <ListBucketResult>
      <Name>quiz-test</Name>
      <IsTruncated>#{not last?}</IsTruncated>
      #{token}
      #{contents}
    </ListBucketResult>
    """
  end

  test "lists the prefix and deletes every key, page by page" do
    stub_bucket([["uploads/7/a.png", "uploads/7/b.png"], ["uploads/7/c.png"]])

    assert :ok = R2.delete_prefix("uploads/7/")

    assert_received {:listed, %{"prefix" => "uploads/7/"}}
    assert_received {:deleted, [["uploads/7/a.png"], ["uploads/7/b.png"]]}
    assert_received {:listed, %{"continuation-token" => "page-1"}}
    assert_received {:deleted, [["uploads/7/c.png"]]}
  end

  test "is a no-op when nothing is stored under the prefix" do
    stub_bucket([[]])

    assert :ok = R2.delete_prefix("uploads/7/")
    refute_received {:deleted, _}
  end

  test "reports keys R2 refused to delete" do
    stub_bucket(
      [["uploads/7/a.png"]],
      "<DeleteResult><Error><Key>uploads/7/a.png</Key><Code>AccessDenied</Code></Error></DeleteResult>"
    )

    assert {:error, {:delete_failed, _}} = R2.delete_prefix("uploads/7/")
  end
end
