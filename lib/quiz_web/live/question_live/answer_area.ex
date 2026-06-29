defmodule QuizWeb.QuestionLive.AnswerArea do
  @moduledoc """
  Participant-facing renderers for a question. Used both by the smartphone
  preview (`QuizWeb.GameLive.Preview`) and the "Ansehen" mode of the questions
  view (`QuizWeb.QuestionLive.Index`).

  Each clause carries its own colocated `phx-hook` for interactive types
  (sequence reorder, matching drag & drop, pin placement).
  """
  use QuizWeb, :html

  attr :question, :map, required: true

  def answer_area(%{question: %{type: :text_input}} = assigns) do
    ~H"""
    <input
      type="text"
      name="answer"
      placeholder="Antwort eintippen …"
      class={["w-full h-14 text-lg", field_base_class(), field_state_class([])]}
    />
    """
  end

  def answer_area(%{question: %{type: :single_choice}} = assigns) do
    ~H"""
    <ul class="space-y-2 list-none p-0">
      <li :for={{choice, idx} <- Enum.with_index(@question.data.choices)}>
        <label class="flex items-center gap-3 rounded-box bg-base-200 px-3 py-2 cursor-pointer hover:bg-base-300 transition">
          <input
            type="radio"
            name="answer"
            value={idx}
            class="radio radio-primary"
          />
          <span class="text-sm">{choice.text}</span>
        </label>
      </li>
    </ul>
    """
  end

  def answer_area(%{question: %{type: :sequence}} = assigns) do
    ~H"""
    <div id={"preview-sequence-#{@question.id}"} phx-hook=".PreviewSortable" phx-update="ignore">
      <input type="hidden" name="answer" data-answer />
      <p class="mb-2 flex items-center gap-1.5 text-[11px] font-mono uppercase tracking-wider text-base-content/50">
        <.drag_grip class="size-3" /> Ziehen zum Sortieren
      </p>
      <ul data-list class="space-y-2 list-none p-0">
        <li
          :for={item <- @question.data.items}
          data-id={item.id}
          class="flex items-center gap-2 rounded-box bg-base-200 px-3 py-2 ring-1 ring-inset ring-base-300/60"
        >
          <button
            type="button"
            data-handle
            aria-label="Sortieren"
            class="grid place-items-center min-w-11 min-h-11 -my-1.5 cursor-grab active:cursor-grabbing text-base-content/50 hover:text-base-content/80 select-none touch-none"
          >
            <.drag_grip class="size-4" />
          </button>
          <span class="flex-1 text-sm">{item.text}</span>
        </li>
      </ul>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PreviewSortable">
      export default {
        mounted() {
          const el = this.el;
          const list = el.querySelector("[data-list]");
          const input = el.querySelector("[data-answer]");

          const sync = () => {
            const ids = [...list.querySelectorAll("li")].map((li) => li.dataset.id);
            if (input) input.value = ids.join(",");
          };
          sync();

          // Pointer-driven drag (works for mouse, touch and pen). Native HTML5
          // drag-and-drop never fires from touch on mobile Firefox/iOS Safari,
          // so we reorder manually based on the pointer's Y position.
          const THRESHOLD = 6;   // px of movement before a drag actually starts
          const EDGE = 60;       // px band near the viewport edge that auto-scrolls
          let start = null;      // { id, li, x, y } captured on pointerdown
          let dragging = null;   // the <li> currently being dragged
          let ghost = null;      // floating clone that follows the finger

          const makeGhost = (li) => {
            const r = li.getBoundingClientRect();
            const g = li.cloneNode(true);
            g.style.position = "fixed";
            g.style.left = r.left + "px";
            g.style.top = r.top + "px";
            g.style.width = r.width + "px";
            g.style.margin = "0";
            g.style.pointerEvents = "none";
            g.style.zIndex = "9999";
            g.classList.add("opacity-90", "shadow-lg", "rotate-1");
            document.body.appendChild(g);
            return g;
          };

          const moveGhost = (x, y) => {
            if (!ghost || !start) return;
            ghost.style.left = x - start.dx + "px";
            ghost.style.top = y - start.dy + "px";
          };

          const reorder = (y) => {
            const siblings = [...list.querySelectorAll("li:not(.opacity-40)")];
            const after = siblings.find((s) => {
              const r = s.getBoundingClientRect();
              return y < r.top + r.height / 2;
            });
            if (after) {
              if (after !== dragging.nextSibling) list.insertBefore(dragging, after);
            } else if (list.lastElementChild !== dragging) {
              list.appendChild(dragging);
            }
          };

          const autoScroll = (y) => {
            if (y < EDGE) window.scrollBy(0, -10);
            else if (y > window.innerHeight - EDGE) window.scrollBy(0, 10);
          };

          const onDown = (e) => {
            const handle = e.target.closest("[data-handle]");
            if (!handle) return;
            const li = handle.closest("li");
            if (!li || li.parentElement !== list) return;
            const r = li.getBoundingClientRect();
            start = { li, x: e.clientX, y: e.clientY, dx: e.clientX - r.left, dy: e.clientY - r.top };
            handle.setPointerCapture(e.pointerId);
            e.preventDefault();
          };

          const begin = () => {
            dragging = start.li;
            dragging.classList.add("opacity-40");
            ghost = makeGhost(dragging);
            if (navigator.vibrate) navigator.vibrate(10);
          };

          const onMove = (e) => {
            if (!start) return;
            if (!dragging) {
              if (Math.abs(e.clientX - start.x) < THRESHOLD &&
                  Math.abs(e.clientY - start.y) < THRESHOLD) return;
              begin();
            }
            e.preventDefault();
            moveGhost(e.clientX, e.clientY);
            reorder(e.clientY);
            autoScroll(e.clientY);
          };

          const onUp = () => {
            if (dragging) {
              dragging.classList.remove("opacity-40");
              dragging = null;
              ghost?.remove();
              ghost = null;
              sync();
            }
            start = null;
          };

          list.addEventListener("pointerdown", onDown);
          list.addEventListener("pointermove", onMove);
          list.addEventListener("pointerup", onUp);
          list.addEventListener("pointercancel", onUp);
        },
      };
    </script>
    """
  end

  def answer_area(%{question: %{type: :matching}} = assigns) do
    ~H"""
    <div id={"preview-match-#{@question.id}"} phx-hook=".PreviewMatch" phx-update="ignore">
      <input type="hidden" name="answer" data-answer />
      <ul class="space-y-2.5 list-none p-0">
        <li
          :for={pair <- @question.data.pairs}
          class="flex flex-col gap-1.5"
        >
          <span class="text-sm font-semibold break-words">
            {pair.left_text}
          </span>
          <div
            data-slot
            data-pair-id={pair.id}
            class="w-full min-h-11 flex items-stretch rounded-box border-2 border-dashed border-base-300 p-1 transition-colors"
          >
            <span data-placeholder class="flex-1 grid place-items-center text-xs text-base-content/40">
              Hierher ziehen
            </span>
          </div>
        </li>
      </ul>

      <p class="mt-5 mb-2 flex items-center gap-1.5 text-[11px] font-mono uppercase tracking-wider text-base-content/50">
        <.drag_grip class="size-3" /> Ziehen zum Zuordnen
      </p>
      <div
        data-pool
        class="flex flex-wrap gap-2 rounded-box bg-base-200/70 p-3 min-h-16 transition-colors"
      >
        <div
          :for={value <- Enum.shuffle(Enum.map(@question.data.pairs, & &1.right_text))}
          data-chip
          class="match-chip inline-flex items-center justify-between gap-1.5 rounded-box border border-base-300 bg-base-100 pl-1.5 pr-3 py-2 text-sm font-medium shadow-sm cursor-grab active:cursor-grabbing select-none touch-none transition hover:shadow-md hover:-translate-y-px"
        >
          <span class="inline-flex min-w-0 items-center gap-1.5">
            <.drag_grip class="size-3.5 opacity-50" />
            <span data-value class="truncate">{value}</span>
          </span>
          <button
            type="button"
            data-remove
            aria-label="Zurücklegen"
            class="hidden -mr-1 grid place-items-center size-5 rounded-full text-primary-content/70 hover:text-primary-content hover:bg-primary-content/20 leading-none"
          >
            <.icon name="hero-x-mark" class="size-3.5" />
          </button>
        </div>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PreviewMatch">
      export default {
        mounted() {
          const el = this.el;
          const pool = el.querySelector("[data-pool]");
          const input = el.querySelector("[data-answer]");
          let dragging = null;

          // Serialize the current slot assignments into the hidden input as a
          // { pair_id: chosen_right_text } JSON map for the form submit.
          const sync = () => {
            const map = {};
            el.querySelectorAll("[data-slot]").forEach((slot) => {
              const chip = slot.querySelector("[data-chip] [data-value]");
              if (chip) map[slot.dataset.pairId] = chip.textContent;
            });
            if (input) input.value = JSON.stringify(map);
          };

          // Styling that differs between a chip resting in the pool vs. dropped
          // into a slot (where it fills the row and gets the "filled" accent).
          const POOL_CLS = ["bg-base-100", "border-base-300", "shadow-sm", "w-auto"];
          const SLOT_CLS = ["bg-primary", "text-primary-content", "border-primary", "shadow", "w-full", "h-full", "!py-0"];

          const styleChip = (chip) => {
            const inSlot = chip.closest("[data-slot]") !== null;
            chip.classList.remove(...(inSlot ? POOL_CLS : SLOT_CLS));
            chip.classList.add(...(inSlot ? SLOT_CLS : POOL_CLS));
            const remove = chip.querySelector("[data-remove]");
            if (remove) remove.classList.toggle("hidden", !inSlot);
          };

          const refreshPlaceholder = (slot) => {
            const ph = slot.querySelector("[data-placeholder]");
            if (ph) ph.classList.toggle("hidden", slot.querySelector("[data-chip]") !== null);
          };

          const returnToPool = (chip) => {
            pool.appendChild(chip);
            styleChip(chip);
          };

          const HILITE = ["border-primary", "bg-primary/5"];
          const clearHighlights = () => {
            el.querySelectorAll("[data-slot]").forEach((s) => s.classList.remove(...HILITE));
            pool.classList.remove("bg-primary/5");
          };

          el.querySelectorAll("[data-chip]").forEach(styleChip);
          sync();

          // Pointer-driven drag (mouse, touch and pen). Native HTML5 drag-and-drop
          // never fires from touch on mobile Firefox/iOS Safari, so we move a
          // floating clone and resolve the drop target via elementFromPoint.
          const THRESHOLD = 6;   // px of movement before a drag actually starts
          const EDGE = 60;       // px band near the viewport edge that auto-scrolls
          let start = null;      // { chip, x, y, dx, dy } captured on pointerdown
          let ghost = null;      // floating clone that follows the finger

          // elementFromPoint would hit the ghost (it sits on top); pointer-events:
          // none keeps it transparent to hit-testing, but guard anyway.
          const targetAt = (x, y) => {
            const node = document.elementFromPoint(x, y);
            return node ? (node.closest("[data-slot]") || node.closest("[data-pool]")) : null;
          };

          const moveGhost = (x, y) => {
            if (!ghost || !start) return;
            ghost.style.left = x - start.dx + "px";
            ghost.style.top = y - start.dy + "px";
          };

          const autoScroll = (y) => {
            if (y < EDGE) window.scrollBy(0, -10);
            else if (y > window.innerHeight - EDGE) window.scrollBy(0, 10);
          };

          const begin = () => {
            dragging = start.chip;
            dragging.classList.add("opacity-40");
            const r = dragging.getBoundingClientRect();
            ghost = dragging.cloneNode(true);
            ghost.style.position = "fixed";
            ghost.style.left = r.left + "px";
            ghost.style.top = r.top + "px";
            ghost.style.width = r.width + "px";
            ghost.style.margin = "0";
            ghost.style.pointerEvents = "none";
            ghost.style.zIndex = "9999";
            ghost.classList.add("opacity-90", "shadow-lg", "rotate-2");
            document.body.appendChild(ghost);
            if (navigator.vibrate) navigator.vibrate(10);
          };

          el.addEventListener("pointerdown", (e) => {
            // Ignore the remove button so tap-to-remove still works.
            if (e.target.closest("[data-remove]")) return;
            const chip = e.target.closest("[data-chip]");
            if (!chip) return;
            const r = chip.getBoundingClientRect();
            start = { chip, x: e.clientX, y: e.clientY, dx: e.clientX - r.left, dy: e.clientY - r.top };
            chip.setPointerCapture(e.pointerId);
            e.preventDefault();
          });

          el.addEventListener("pointermove", (e) => {
            if (!start) return;
            if (!dragging) {
              if (Math.abs(e.clientX - start.x) < THRESHOLD &&
                  Math.abs(e.clientY - start.y) < THRESHOLD) return;
              begin();
            }
            e.preventDefault();
            moveGhost(e.clientX, e.clientY);
            autoScroll(e.clientY);
            const target = targetAt(e.clientX, e.clientY);
            clearHighlights();
            if (target?.matches("[data-slot]")) target.classList.add(...HILITE);
            else if (target?.matches("[data-pool]")) pool.classList.add("bg-primary/5");
          });

          const onUp = (e) => {
            if (dragging) {
              const target = targetAt(e.clientX, e.clientY);
              const slot = target?.matches("[data-slot]") ? target : null;
              const fromSlot = dragging.closest("[data-slot]");

              if (slot) {
                const occupant = slot.querySelector("[data-chip]");
                if (occupant && occupant !== dragging) returnToPool(occupant);
                slot.appendChild(dragging);
              } else if (target?.matches("[data-pool]")) {
                pool.appendChild(dragging);
              }

              styleChip(dragging);
              if (fromSlot && fromSlot !== slot) refreshPlaceholder(fromSlot);
              if (slot) refreshPlaceholder(slot);
              clearHighlights();
              dragging.classList.remove("opacity-40");
              ghost?.remove();
              ghost = null;
              dragging = null;
              sync();
            }
            start = null;
          };
          el.addEventListener("pointerup", onUp);
          el.addEventListener("pointercancel", onUp);

          el.addEventListener("click", (e) => {
            const remove = e.target.closest("[data-remove]");
            if (!remove) return;
            const chip = remove.closest("[data-chip]");
            const slot = chip.closest("[data-slot]");
            returnToPool(chip);
            if (slot) refreshPlaceholder(slot);
            sync();
          });
        },
      };
    </script>
    """
  end

  def answer_area(%{question: %{type: :pin_on_image, data: %{pin: pin}}} = assigns)
      when not is_nil(pin) do
    ~H"""
    <div
      id={"preview-pin-#{@question.id}"}
      phx-hook=".PreviewPin"
      phx-update="ignore"
      class="relative w-full overflow-hidden rounded-box bg-base-200 cursor-crosshair select-none"
      style={"aspect-ratio: #{@question.data.pin.aspect_ratio || 1.0};"}
    >
      <img
        src={Quiz.Storage.url(@question.data.pin.image_key)}
        class="absolute inset-0 w-full h-full object-cover pointer-events-none"
        alt="Bild"
      />
      <input type="hidden" name="answer[x]" data-answer-x />
      <input type="hidden" name="answer[y]" data-answer-y />
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PreviewPin">
      export default {
        mounted() {
          const el = this.el;
          const inputX = el.querySelector("[data-answer-x]");
          const inputY = el.querySelector("[data-answer-y]");
          const marker = document.createElement("div");
          marker.className =
            "absolute size-4 rounded-full bg-primary ring-2 ring-white shadow -translate-x-1/2 -translate-y-1/2 hidden";
          el.appendChild(marker);

          el.addEventListener("click", (e) => {
            const r = el.getBoundingClientRect();
            const x = Math.min(Math.max((e.clientX - r.left) / r.width, 0), 1);
            const y = Math.min(Math.max((e.clientY - r.top) / r.height, 0), 1);
            marker.style.left = x * 100 + "%";
            marker.style.top = y * 100 + "%";
            marker.classList.remove("hidden");
            // Mirror the placed pin into the hidden inputs so the surrounding
            // form submits the normalized 0..1 coordinates.
            if (inputX) inputX.value = x;
            if (inputY) inputY.value = y;
          });
        },
      };
    </script>
    """
  end

  def answer_area(assigns) do
    ~H"""
    <p class="text-sm text-base-content/60">Unbekannter Fragetyp.</p>
    """
  end

  @doc """
  Read-only summary of a submitted answer, for the confirmation card. `answer` is
  the canonical value stored on `Answer` (`payload["value"]`).
  """
  attr :question, :map, required: true
  attr :answer, :any, required: true

  def answer_summary(%{question: %{type: :text_input}} = assigns) do
    ~H"""
    <p class="text-2xl font-display font-extrabold text-primary break-words">
      {to_string(@answer)}
    </p>
    """
  end

  def answer_summary(%{question: %{type: :single_choice}} = assigns) do
    assigns = assign(assigns, :choice, choice_at(assigns.question, assigns.answer))

    ~H"""
    <p class="text-xl font-bold text-primary break-words">
      {@choice || "—"}
    </p>
    """
  end

  def answer_summary(%{question: %{type: :sequence}} = assigns) do
    assigns = assign(assigns, :ordered, sequence_texts(assigns.question, assigns.answer))

    ~H"""
    <ol class="list-none p-0 space-y-1">
      <li :for={{text, idx} <- Enum.with_index(@ordered, 1)} class="flex items-baseline gap-2">
        <span class="font-display font-bold text-primary/50 tabular-nums">{idx}.</span>
        <span class="font-medium text-primary break-words">{text}</span>
      </li>
    </ol>
    """
  end

  def answer_summary(%{question: %{type: :matching}} = assigns) do
    assigns = assign(assigns, :rows, matching_rows(assigns.question, assigns.answer))

    ~H"""
    <ul class="list-none p-0 space-y-1.5">
      <li :for={{left, right} <- @rows} class="flex items-center gap-2 text-sm">
        <span class="font-semibold text-primary break-words">{left}</span>
        <.icon name="hero-arrow-right" class="size-4 text-base-content/30 shrink-0" />
        <span class="text-primary/80 break-words">{right || "—"}</span>
      </li>
    </ul>
    """
  end

  def answer_summary(%{question: %{type: :pin_on_image}} = assigns) do
    ~H"""
    <p class="text-base font-semibold text-primary">Position markiert</p>
    """
  end

  def answer_summary(assigns) do
    ~H"""
    <p class="text-base text-primary">Antwort gespeichert</p>
    """
  end

  defp choice_at(%{data: %{choices: choices}}, index) when is_integer(index) do
    case Enum.at(choices, index) do
      %{text: text} -> text
      _ -> nil
    end
  end

  defp choice_at(_question, _index), do: nil

  defp sequence_texts(%{data: %{items: items}}, ids) when is_list(ids) do
    by_id = Map.new(items, &{&1.id, &1.text})
    Enum.map(ids, &Map.get(by_id, &1, "?"))
  end

  defp sequence_texts(_question, _ids), do: []

  defp matching_rows(%{data: %{pairs: pairs}}, answer) when is_map(answer) do
    Enum.map(pairs, fn pair ->
      {pair.left_text, Map.get(answer, pair.id) || Map.get(answer, to_string(pair.id))}
    end)
  end

  defp matching_rows(_question, _answer), do: []

  @doc """
  Prepares a question for participant display. Sequence items are shuffled so
  the original order is not given away; other types pass through unchanged.
  """
  def prepare_question(%{type: :sequence, data: data} = question) do
    %{question | data: %{data | items: Enum.shuffle(data.items)}}
  end

  def prepare_question(question), do: question

  # Six-dot "grip" glyph signalling a draggable element. Shared by the sequence
  # handle and the matching chips so the drag affordance reads the same way.
  attr :class, :string, default: nil

  defp drag_grip(assigns) do
    ~H"""
    <svg class={["shrink-0", @class]} viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
      <circle cx="7" cy="5" r="1.5" />
      <circle cx="13" cy="5" r="1.5" />
      <circle cx="7" cy="10" r="1.5" />
      <circle cx="13" cy="10" r="1.5" />
      <circle cx="7" cy="15" r="1.5" />
      <circle cx="13" cy="15" r="1.5" />
    </svg>
    """
  end
end
