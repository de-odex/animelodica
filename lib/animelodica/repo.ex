defmodule Animelodica.Repo do
  use Ecto.Repo,
    otp_app: :animelodica,
    adapter: Ecto.Adapters.Postgres
end
