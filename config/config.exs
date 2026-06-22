# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :quiz, :scopes,
  user: [
    default: true,
    module: Quiz.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Quiz.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :quiz,
  ecto_repos: [Quiz.Repo],
  generators: [timestamp_type: :utc_datetime]

# The UI is German throughout, so default all Gettext output (including the
# built-in Ecto/changeset error messages) to German.
config :quiz, QuizWeb.Gettext, default_locale: "de", locales: ~w(de en)

# User-upload storage. Defaults to local disk everywhere; prod swaps in the
# Cloudflare R2 adapter via config/runtime.exs when credentials are present.
config :quiz, Quiz.Storage, adapter: Quiz.Storage.Local
config :quiz, Quiz.Storage.Local, dir: Path.join(["priv", "static", "uploads"])

# ex_aws uses Req (built on Finch) as its HTTP client instead of the default
# hackney, keeping the app on a single, modern HTTP stack.
config :ex_aws, http_client: ExAws.Request.Req

# Configure the endpoint
config :quiz, QuizWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: QuizWeb.ErrorHTML, json: QuizWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Quiz.PubSub,
  live_view: [signing_salt: "1QmyG0xb"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  quiz: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  quiz: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
