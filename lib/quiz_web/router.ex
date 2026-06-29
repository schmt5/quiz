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
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuizWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:quiz, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QuizWeb.Telemetry
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
