defmodule QuizWeb.Router do
  use QuizWeb, :router

  import QuizWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuizWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", QuizWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sponsors", PageController, :sponsors
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuizWeb do
  #   pipe_through :api
  # end

  # LiveDashboard, in every environment, behind HTTP Basic Auth. Credentials
  # come from the :dashboard_auth config (dev.exs / runtime.exs); without them
  # the route answers 404, so a prod deploy missing the secret exposes nothing.
  import Phoenix.LiveDashboard.Router

  pipeline :admin_basic_auth do
    plug :dashboard_auth
  end

  scope "/admin" do
    pipe_through [:browser, :admin_basic_auth]

    live_dashboard "/dashboard", metrics: QuizWeb.Telemetry
  end

  defp dashboard_auth(conn, _opts) do
    case Application.get_env(:quiz, :dashboard_auth) do
      nil -> conn |> send_resp(:not_found, "Not Found") |> halt()
      credentials -> Plug.BasicAuth.basic_auth(conn, credentials)
    end
  end

  ## Authentication routes

  scope "/", QuizWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{QuizWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit

      live "/games", GameLive.Index, :index
      live "/games/new", GameLive.Form, :new
      live "/games/:id", GameLive.Show, :show
      live "/games/:id/edit", GameLive.Form, :edit

      live "/games/:game_id/questions", QuestionLive.Index, :index
      live "/games/:game_id/questions/reorder", QuestionLive.Reorder, :index
      live "/games/:game_id/questions/:id/edit", QuestionLive.Index, :edit

      live "/games/:game_id/preview", GameLive.Preview, :show

      live "/games/:id/run", RunLive.Host, :show
      live "/games/:id/review/:position", RunLive.Review, :show
      live "/games/:id/correction", CorrectionLive.Index, :index
      live "/games/:id/correction/:position", CorrectionLive.Question, :show
      live "/games/:id/leaderboard", LeaderboardLive.Show, :show
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", QuizWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{QuizWeb.UserAuth, :mount_current_scope}] do
      live "/styleguide", StyleguideLive, :index
      # Public registration is disabled for now; re-add the line below to re-enable.
      # live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new

      live "/join", PlayLive.Join, :new
      live "/play/:join_code", PlayLive.Play, :show
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
