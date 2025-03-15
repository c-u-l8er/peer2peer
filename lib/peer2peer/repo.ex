defmodule Peer2peer.Repo do
  use Ecto.Repo,
    otp_app: :peer2peer,
    adapter: Ecto.Adapters.Postgres
end
