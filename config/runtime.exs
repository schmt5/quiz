import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/quiz start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :quiz, QuizWeb.Endpoint, server: true
end

# Use Cloudflare R2 for uploads when credentials are present; otherwise fall
# back to the local-disk adapter configured in config/config.exs. This keeps
# the R2 path dormant until the bucket and tokens are provisioned.
if r2_key = System.get_env("R2_ACCESS_KEY_ID") do
  config :quiz, Quiz.Storage, adapter: Quiz.Storage.R2

  config :quiz, Quiz.Storage.R2,
    bucket: System.fetch_env!("R2_BUCKET"),
    public_base_url: System.fetch_env!("R2_PUBLIC_BASE_URL")

  config :ex_aws, :s3,
    access_key_id: r2_key,
    secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY"),
    region: "auto",
    scheme: "https://",
    host: System.fetch_env!("R2_ENDPOINT")

  config :ex_aws,
    json_codec: Jason,
    access_key_id: r2_key,
    secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY")
end

config :quiz, QuizWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :quiz, Quiz.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "50"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # LiveDashboard at /admin/dashboard. Without DASHBOARD_PASSWORD the route
  # stays a 404 — set it via `fly secrets set DASHBOARD_PASSWORD=...`.
  if dashboard_password = System.get_env("DASHBOARD_PASSWORD") do
    config :quiz, :dashboard_auth,
      username: System.get_env("DASHBOARD_USERNAME") || "quiz",
      password: dashboard_password
  end

  config :quiz, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :quiz, QuizWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    # Every host the app is reachable under. Without an explicit list, Phoenix
    # only accepts WebSocket connections whose Origin matches `url[:host]`
    # (PHX_HOST) — pages on the other domains would load but LiveView would
    # never connect (participants stuck on the "Verbinde …" spinner).
    check_origin: [
      "https://waerweiss.ch",
      "https://www.waerweiss.ch",
      "https://along-quiz.fly.dev"
    ],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :quiz, QuizWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :quiz, QuizWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
