defmodule QuizWeb.StyleguideLive do
  use QuizWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl space-y-10">
        <.header>
          Styleguide
          <:subtitle>
            daisyUI semantic colors as configured in <code>assets/css/app.css</code>.
          </:subtitle>
        </.header>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Base surfaces</h2>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div class="bg-base-100 text-base-content border border-base-300 rounded-box p-4">
              <p class="font-semibold">base-100</p>
              <p class="text-sm opacity-70">Default page background</p>
            </div>
            <div class="bg-base-200 text-base-content rounded-box p-4">
              <p class="font-semibold">base-200</p>
              <p class="text-sm opacity-70">Subtle elevation</p>
            </div>
            <div class="bg-base-300 text-base-content rounded-box p-4">
              <p class="font-semibold">base-300</p>
              <p class="text-sm opacity-70">Stronger elevation</p>
            </div>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Text</h2>
          <div class="space-y-1">
            <p class="text-base-content">base-content — body text</p>
            <p class="text-base-content/70">base-content/70 — muted</p>
            <p class="text-base-content/50">base-content/50 — more muted</p>
            <p class="text-primary">text-primary — the quick brown fox</p>
            <p class="text-secondary">text-secondary — the quick brown fox</p>
            <p class="text-accent">text-accent — the quick brown fox</p>
            <p class="text-neutral">text-neutral — the quick brown fox</p>
            <p class="text-info">text-info — the quick brown fox</p>
            <p class="text-success">text-success — the quick brown fox</p>
            <p class="text-warning">text-warning — the quick brown fox</p>
            <p class="text-error">text-error — the quick brown fox</p>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Buttons — solid</h2>
          <div class="flex flex-wrap gap-2">
            <button class="btn">default</button>
            <button class="btn btn-primary">primary</button>
            <button class="btn btn-secondary">secondary</button>
            <button class="btn btn-accent">accent</button>
            <button class="btn btn-neutral">neutral</button>
            <button class="btn btn-info">info</button>
            <button class="btn btn-success">success</button>
            <button class="btn btn-warning">warning</button>
            <button class="btn btn-error">error</button>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Buttons — soft</h2>
          <div class="flex flex-wrap gap-2">
            <button class="btn btn-soft btn-primary">primary</button>
            <button class="btn btn-soft btn-secondary">secondary</button>
            <button class="btn btn-soft btn-accent">accent</button>
            <button class="btn btn-soft btn-neutral">neutral</button>
            <button class="btn btn-soft btn-info">info</button>
            <button class="btn btn-soft btn-success">success</button>
            <button class="btn btn-soft btn-warning">warning</button>
            <button class="btn btn-soft btn-error">error</button>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Buttons — outline</h2>
          <div class="flex flex-wrap gap-2">
            <button class="btn btn-outline btn-primary">primary</button>
            <button class="btn btn-outline btn-secondary">secondary</button>
            <button class="btn btn-outline btn-accent">accent</button>
            <button class="btn btn-outline btn-neutral">neutral</button>
            <button class="btn btn-outline btn-info">info</button>
            <button class="btn btn-outline btn-success">success</button>
            <button class="btn btn-outline btn-warning">warning</button>
            <button class="btn btn-outline btn-error">error</button>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Buttons — ghost & link</h2>
          <div class="flex flex-wrap gap-2">
            <button class="btn btn-ghost text-primary">ghost primary</button>
            <button class="btn btn-ghost text-secondary">ghost secondary</button>
            <button class="btn btn-ghost text-accent">ghost accent</button>
            <button class="btn btn-ghost text-neutral">ghost neutral</button>
            <button class="btn btn-ghost text-info">ghost info</button>
            <button class="btn btn-ghost text-success">ghost success</button>
            <button class="btn btn-ghost text-warning">ghost warning</button>
            <button class="btn btn-ghost text-error">ghost error</button>
          </div>
          <div class="flex flex-wrap gap-4">
            <a class="link link-primary">link primary</a>
            <a class="link link-secondary">link secondary</a>
            <a class="link link-accent">link accent</a>
            <a class="link link-neutral">link neutral</a>
            <a class="link link-info">link info</a>
            <a class="link link-success">link success</a>
            <a class="link link-warning">link warning</a>
            <a class="link link-error">link error</a>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Color swatches (bg + matching content)</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <div class="bg-primary text-primary-content rounded-box p-4">
              <p class="font-semibold">Primary</p>
              <p class="text-sm opacity-80">bg-primary / text-primary-content</p>
            </div>
            <div class="bg-secondary text-secondary-content rounded-box p-4">
              <p class="font-semibold">Secondary</p>
              <p class="text-sm opacity-80">bg-secondary / text-secondary-content</p>
            </div>
            <div class="bg-accent text-accent-content rounded-box p-4">
              <p class="font-semibold">Accent</p>
              <p class="text-sm opacity-80">bg-accent / text-accent-content</p>
            </div>
            <div class="bg-neutral text-neutral-content rounded-box p-4">
              <p class="font-semibold">Neutral</p>
              <p class="text-sm opacity-80">bg-neutral / text-neutral-content</p>
            </div>
            <div class="bg-info text-info-content rounded-box p-4">
              <p class="font-semibold">Info</p>
              <p class="text-sm opacity-80">bg-info / text-info-content</p>
            </div>
            <div class="bg-success text-success-content rounded-box p-4">
              <p class="font-semibold">Success</p>
              <p class="text-sm opacity-80">bg-success / text-success-content</p>
            </div>
            <div class="bg-warning text-warning-content rounded-box p-4">
              <p class="font-semibold">Warning</p>
              <p class="text-sm opacity-80">bg-warning / text-warning-content</p>
            </div>
            <div class="bg-error text-error-content rounded-box p-4">
              <p class="font-semibold">Error</p>
              <p class="text-sm opacity-80">bg-error / text-error-content</p>
            </div>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Badges</h2>
          <div class="flex flex-wrap gap-2">
            <span class="badge badge-primary">primary</span>
            <span class="badge badge-secondary">secondary</span>
            <span class="badge badge-accent">accent</span>
            <span class="badge badge-neutral">neutral</span>
            <span class="badge badge-info">info</span>
            <span class="badge badge-success">success</span>
            <span class="badge badge-warning">warning</span>
            <span class="badge badge-error">error</span>
          </div>
          <div class="flex flex-wrap gap-2">
            <span class="badge badge-soft badge-primary">soft primary</span>
            <span class="badge badge-soft badge-secondary">soft secondary</span>
            <span class="badge badge-soft badge-accent">soft accent</span>
            <span class="badge badge-soft badge-neutral">soft neutral</span>
            <span class="badge badge-soft badge-info">soft info</span>
            <span class="badge badge-soft badge-success">soft success</span>
            <span class="badge badge-soft badge-warning">soft warning</span>
            <span class="badge badge-soft badge-error">soft error</span>
          </div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Alerts</h2>
          <div class="alert alert-info"><span>alert-info message</span></div>
          <div class="alert alert-success"><span>alert-success message</span></div>
          <div class="alert alert-warning"><span>alert-warning message</span></div>
          <div class="alert alert-error"><span>alert-error message</span></div>
        </section>

        <section class="space-y-4">
          <h2 class="text-xl font-semibold">Form inputs</h2>
          <form class="space-y-3 max-w-md">
            <input type="text" class="input w-full" placeholder="default input" />
            <input type="text" class="input input-primary w-full" placeholder="input-primary" />
            <input type="text" class="input input-secondary w-full" placeholder="input-secondary" />
            <input type="text" class="input input-accent w-full" placeholder="input-accent" />
            <input type="text" class="input input-neutral w-full" placeholder="input-neutral" />
            <input type="text" class="input input-info w-full" placeholder="input-info" />
            <input type="text" class="input input-success w-full" placeholder="input-success" />
            <input type="text" class="input input-warning w-full" placeholder="input-warning" />
            <input type="text" class="input input-error w-full" placeholder="input-error" />
          </form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
