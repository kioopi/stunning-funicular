defmodule Quiz.PlayerNotifier.Supervisor do
  @moduledoc """
  Supervisor to hold the PlayerNotifiers for one round.
  Creates a PlayerNotifier Process for every element in `players`.
  """
  def start_link(round_id, players) do
    children = Enum.map(players, fn(player) -> Quiz.PlayerNotifier.child_spec(round_id, player) end)

    opts = [strategy: :one_for_one]

    Supervisor.start_link(children, opts)
  end
end
