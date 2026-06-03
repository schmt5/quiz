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
      placeholder="Deine Antwort"
      class="input input-bordered w-full"
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
            name={"choice-#{@question.id}"}
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
    <ul
      id={"preview-sequence-#{@question.id}"}
      phx-hook=".PreviewSortable"
      phx-update="ignore"
      class="space-y-2 list-none p-0"
    >
      <li
        :for={item <- @question.data.items}
        class="flex items-center gap-2 rounded-box bg-base-200 px-3 py-2"
      >
        <button
          type="button"
          data-handle
          aria-label="Sortieren"
          class="cursor-grab active:cursor-grabbing text-base-content/40 hover:text-base-content/70 px-1 select-none touch-none"
        >
          <svg class="size-4" viewBox="0 0 20 20" fill="currentColor">
            <circle cx="7" cy="5" r="1.5" />
            <circle cx="13" cy="5" r="1.5" />
            <circle cx="7" cy="10" r="1.5" />
            <circle cx="13" cy="10" r="1.5" />
            <circle cx="7" cy="15" r="1.5" />
            <circle cx="13" cy="15" r="1.5" />
          </svg>
        </button>
        <span class="text-sm">{item.text}</span>
      </li>
    </ul>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PreviewSortable">
      export default {
        mounted() {
          const el = this.el;
          let dragging = null;

          const bindHandles = () => {
            el.querySelectorAll("[data-handle]").forEach((h) => {
              if (h.dataset.bound) return;
              h.dataset.bound = "1";
              const li = h.closest("li");
              h.addEventListener("mousedown", () => li.setAttribute("draggable", "true"));
              h.addEventListener("mouseup", () => li.removeAttribute("draggable"));
              h.addEventListener("mouseleave", () => li.removeAttribute("draggable"));
            });
          };
          bindHandles();
          this.observer = new MutationObserver(bindHandles);
          this.observer.observe(el, { childList: true });

          el.addEventListener("dragstart", (e) => {
            const li = e.target.closest("li");
            if (!li || li.parentElement !== el) return;
            dragging = li;
            li.classList.add("opacity-40");
            e.dataTransfer.effectAllowed = "move";
            try { e.dataTransfer.setData("text/plain", ""); } catch (_) {}
          });

          el.addEventListener("dragover", (e) => {
            if (!dragging) return;
            e.preventDefault();
            const siblings = [...el.querySelectorAll("li:not(.opacity-40)")];
            const after = siblings.find((s) => {
              const r = s.getBoundingClientRect();
              return e.clientY < r.top + r.height / 2;
            });
            if (after) {
              if (after !== dragging.nextSibling) el.insertBefore(dragging, after);
            } else {
              if (el.lastElementChild !== dragging) el.appendChild(dragging);
            }
          });

          el.addEventListener("dragend", () => {
            if (!dragging) return;
            dragging.classList.remove("opacity-40");
            dragging.removeAttribute("draggable");
            dragging = null;
          });
        },
        destroyed() { this.observer?.disconnect(); }
      };
    </script>
    """
  end

  def answer_area(%{question: %{type: :matching}} = assigns) do
    ~H"""
    <div id={"preview-match-#{@question.id}"} phx-hook=".PreviewMatch" phx-update="ignore">
      <ul class="space-y-2.5 list-none p-0">
        <li
          :for={pair <- @question.data.pairs}
          class="flex items-center gap-2"
        >
          <span class="flex-1 min-w-0 text-sm font-semibold truncate">
            {pair.left_text}
          </span>
          <.icon name="hero-arrow-right" class="size-4 text-base-content/30 shrink-0" />
          <div
            data-slot
            class="flex-1 min-w-0 h-11 flex items-stretch rounded-box border-2 border-dashed border-base-300 p-1 transition-colors"
          >
            <span data-placeholder class="flex-1 grid place-items-center text-xs text-base-content/40">
              Hierher ziehen
            </span>
          </div>
        </li>
      </ul>

      <p class="mt-5 mb-2 text-[11px] font-mono uppercase tracking-wider text-base-content/50">
        Zuordnungen
      </p>
      <div
        data-pool
        class="flex flex-wrap gap-2 rounded-box bg-base-200/70 p-3 min-h-16 transition-colors"
      >
        <div
          :for={value <- Enum.shuffle(Enum.map(@question.data.pairs, & &1.right_text))}
          data-chip
          draggable="true"
          class="match-chip inline-flex items-center justify-between gap-1.5 rounded-box border border-base-300 bg-base-100 px-3 py-2 text-sm font-medium shadow-sm cursor-grab active:cursor-grabbing select-none touch-none transition hover:shadow-md hover:-translate-y-px"
        >
          <span data-value>{value}</span>
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
          let dragging = null;

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
          const highlight = (e) => {
            clearHighlights();
            const slot = e.target.closest("[data-slot]");
            if (slot) slot.classList.add(...HILITE);
            else if (e.target.closest("[data-pool]")) pool.classList.add("bg-primary/5");
          };

          el.querySelectorAll("[data-chip]").forEach(styleChip);

          el.addEventListener("dragstart", (e) => {
            const chip = e.target.closest("[data-chip]");
            if (!chip) return;
            dragging = chip;
            chip.classList.add("opacity-40");
            e.dataTransfer.effectAllowed = "move";
            try { e.dataTransfer.setData("text/plain", ""); } catch (_) {}
          });

          el.addEventListener("dragend", () => {
            if (dragging) dragging.classList.remove("opacity-40");
            clearHighlights();
            dragging = null;
          });

          el.addEventListener("dragover", (e) => {
            if (dragging && (e.target.closest("[data-slot]") || e.target.closest("[data-pool]"))) {
              e.preventDefault();
              highlight(e);
            }
          });

          el.addEventListener("drop", (e) => {
            if (!dragging) return;
            e.preventDefault();
            clearHighlights();
            const slot = e.target.closest("[data-slot]");
            const fromSlot = dragging.closest("[data-slot]");

            if (slot) {
              const occupant = slot.querySelector("[data-chip]");
              if (occupant && occupant !== dragging) returnToPool(occupant);
              slot.appendChild(dragging);
            } else {
              pool.appendChild(dragging);
            }

            styleChip(dragging);
            if (fromSlot && fromSlot !== slot) refreshPlaceholder(fromSlot);
            if (slot) refreshPlaceholder(slot);
          });

          el.addEventListener("click", (e) => {
            const remove = e.target.closest("[data-remove]");
            if (!remove) return;
            const chip = remove.closest("[data-chip]");
            const slot = chip.closest("[data-slot]");
            returnToPool(chip);
            if (slot) refreshPlaceholder(slot);
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
      class="relative aspect-square w-full overflow-hidden rounded-box bg-base-200 cursor-crosshair select-none"
    >
      <img
        src={Quiz.Storage.url(@question.data.pin.image_key)}
        class="absolute inset-0 w-full h-full object-cover pointer-events-none"
        alt="Bild"
      />
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".PreviewPin">
      export default {
        mounted() {
          const el = this.el;
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
            // Preview is read-only: the placed pin is visual only. In a live
            // game, push the coordinates to the server here, e.g.
            //   this.pushEvent("answer", { x, y })
            // and score them with Question.correct_answer?(question, %{"x"=>x,"y"=>y}).
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
  Prepares a question for participant display. Sequence items are shuffled so
  the original order is not given away; other types pass through unchanged.
  """
  def prepare_question(%{type: :sequence, data: data} = question) do
    %{question | data: %{data | items: Enum.shuffle(data.items)}}
  end

  def prepare_question(question), do: question
end
