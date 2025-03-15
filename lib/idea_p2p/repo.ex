defmodule IdeaP2p.Repo do
  use Ecto.Repo,
    otp_app: :idea_p2p,
    adapter: Ecto.Adapters.Postgres
end
