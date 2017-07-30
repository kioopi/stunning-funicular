defmodule Demo do
  def run do
    start_round(
      :"round_#{:erlang.unique_integer()}",
      ["player_1", "player_2"]
    )
  end

  @doc """
  Starts a AutoPlayer.Server that simulates players of a round.

  After that uses `Quiz.start_playing` to start a new RoundServer
  supervision tree and start the game.
  """
  defp start_round(round_id, player_ids) do
    Demo.AutoPlayer.Server.start_link(round_id, player_ids)

    Quiz.start_playing(
      round_id,
      Enum.map(player_ids, &Demo.AutoPlayer.Server.player_spec(round_id, &1))
    )
  end
end
