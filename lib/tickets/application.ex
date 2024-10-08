defmodule Tickets.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BookingsPipeline
    ]

    opts = [strategy: :one_for_one, name: Tickets.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
