defmodule Demo.AutoPlayer.Server do
  use GenServer

  @behaviour Quiz.PlayerNotifier

  require Logger

  alias Demo.AutoPlayer

  def start_link(round_id, player_ids) do
    GenServer.start_link(__MODULE__, {round_id, player_ids}, name: round_id)
  end

  def player_spec(round_id, player_id) do
    %{ id: player_id, callback_mod: __MODULE__, callback_arg: round_id }
  end

  @doc false

  def next_question(round_id, player_id, question) do
    Logger.debug("AutoPlayer received question #{player_id} #{question.text}")

    GenServer.call(round_id, {:next_question, player_id, question})
  end

  def wrong_answer(round_id, player_id, solution) do
    GenServer.call(round_id, {:wrong_answer, player_id, solution})
  end

  def correct_answer(round_id, player_id) do
    GenServer.call(round_id, {:correct_answer, player_id})
  end

  def won(round_id, player_id) do
    GenServer.call(round_id, {:won, player_id})
  end

  def lost(round_id, player_id) do
    GenServer.call(round_id, {:lost, player_id})
  end

  def init({round_id, _player_ids}) do
    {:ok, %{
      round_id: round_id #,
      #players: player_ids |> Enum.map(&{&1, AutoPlayer.new()}) |> Enum.into(%{})
    }}
  end

  def handle_call({:next_question, player_id, question}, from, state) do
    GenServer.reply(from, :ok) # why is this here?
    IO.puts("#{player_id}: #{question.text}")
    IO.puts("#{player_id}: thinking...")
    next_answer = AutoPlayer.next_answer(question)
    IO.puts("#{player_id}: answer: #{next_answer}")

    Quiz.RoundServer.take_answer(state.round_id, player_id, next_answer)
    {:noreply, state}
  end

  def handle_call({:wrong_answer, player_id, correct_idx}, _from, state) do
    IO.puts("#{player_id}: got it wrong. Correct answer was ##{correct_idx+1}.")
    {:noreply, state}
  end

  def handle_call({:correct_answer, player_id }, _from, state) do
    IO.puts("#{player_id}: got it right!")
    {:noreply, state}
  end

  def handle_call({:won, player_id }, _from, state) do
    IO.puts("#{player_id}: won")
    {:noreply, state}
  end

  def handle_call({:lost, player_id }, _from, state) do
    IO.puts("#{player_id}: lost")
    {:noreply, state}
  end
end

defmodule Demo do
  require Logger

  def run do
    Logger.debug("Demo run")
    start_round(
      :"round_#{:erlang.unique_integer()}",
      ["player_1", "player_2"]
    )
  end

  defp start_round(round_id, player_ids) do
    Demo.AutoPlayer.Server.start_link(round_id, player_ids)

    Quiz.RoundServer.start_playing(
      round_id,
      Enum.map(player_ids, &Demo.AutoPlayer.Server.player_spec(round_id, &1))
    )
  end
end

defmodule Demo.AutoPlayer do
  def next_answer(_question) do
    :timer.sleep(:rand.uniform(:timer.seconds(3)))
    :rand.uniform(4)-1
  end
end
