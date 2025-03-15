# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :peer2peer,
  ecto_repos: [Peer2peer.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :peer2peer, Peer2peerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Peer2peerWeb.ErrorHTML, json: Peer2peerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Peer2peer.PubSub,
  live_view: [signing_salt: "/BLU5NB4ah#&s^d!"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :peer2peer, Peer2peer.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  peer2peer: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  peer2peer: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :peer2peer, Peer2peer.AI,
  providers: [:openai, :anthropic],
  default_provider: :openai,
  openai: [
    api_key: {:system, "OPENAI_API_KEY"},
    organization_id: {:system, "OPENAI_ORGANIZATION_ID"},
    default_model: "gpt-4-turbo"
  ],
  anthropic: [
    api_key: {:system, "ANTHROPIC_API_KEY"},
    default_model: "claude-3-opus"
  ]
