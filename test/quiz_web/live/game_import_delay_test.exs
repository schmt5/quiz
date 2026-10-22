defmodule QuizWeb.GameImportDelayTest do
  # Changes the global preview delay.
  use QuizWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @quiz "Quiz: Pilze\nFrage: Giftig?\nTyp: Single-Choice\n- [x] Fliegenpilz\n- Steinpilz"

  setup do
    previous = Application.get_env(:quiz, :import_preview_delay)
    Application.put_env(:quiz, :import_preview_delay, :timer.hours(1))
    on_exit(fn -> Application.put_env(:quiz, :import_preview_delay, previous) end)
  end

  test "a first paste shows a spinner before the preview" do
    {:ok, lv, _html} = live(build_conn(), ~p"/erstellen")

    lv |> form("#import-form", import: %{text: @quiz}) |> render_change()

    assert has_element?(lv, "#preview-loading")
    refute has_element?(lv, "#preview-title")
    refute has_element?(lv, "#create-quiz")

    # The timer fires: the preview appears.
    send(lv.pid, {:reveal_preview, :sys.get_state(lv.pid).socket.assigns.preview_ref})

    assert has_element?(lv, "#preview-title", "Pilze")
    refute has_element?(lv, "#preview-loading")

    # Later edits update the preview right away.
    lv |> form("#import-form", import: %{text: @quiz <> "\nFrage: Noch eine?"}) |> render_change()
    assert has_element?(lv, "#preview-count", "2 Fragen")
  end

  test "clearing the text while loading drops the pending preview" do
    {:ok, lv, _html} = live(build_conn(), ~p"/erstellen")

    lv |> form("#import-form", import: %{text: @quiz}) |> render_change()
    lv |> form("#import-form", import: %{text: ""}) |> render_change()

    assert has_element?(lv, "#preview-empty")
  end
end
