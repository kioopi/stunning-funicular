defmodule Demo.AutoPlayer.Server do
  use GenServer

  require Logger

  @behaviour Quiz.PlayerNotifier

  alias Demo.AutoPlayer

  def start_link(round_id, player_ids) do
    GenServer.start_link(__MODULE__, {round_id, player_ids}, name: round_id)
  end

  @doc """
  This is _not_ a Supervisor.spec but rather a domain specific defintion of a player.

  round_id is a (dynamically created) atom identifying a round.
  player_id is a string identifying a player.

  """
  def player_spec(round_id, player_id) do
    %{ id: player_id, callback_mod: __MODULE__, callback_arg: round_id }
  end

  @doc false

  def next_question(round_id, player_id, question) do
    GenServer.cast(round_id, {:next_question, player_id, question})
  end

  def wrong_answer(round_id, player_id, solution) do
    GenServer.cast(round_id, {:wrong_answer, player_id, solution})
  end

  def correct_answer(round_id, player_id) do
    GenServer.cast(round_id, {:correct_answer, player_id})
  end

  def won(round_id, player_id) do
    GenServer.cast(round_id, {:won, player_id})
  end

  def lost(round_id, player_id) do
    GenServer.cast(round_id, {:lost, player_id})
  end

  def init({round_id, _player_ids}) do
    {:ok, %{
      round_id: round_id #,
      #players: player_ids |> Enum.map(&{&1, AutoPlayer.new()}) |> Enum.into(%{})
    }}
  end

  def handle_cast({:next_question, player_id, question}, state) do
    IO.puts("#{player_id}: #{question.text}")
    IO.puts("#{player_id}: thinking...")
    next_answer = AutoPlayer.next_answer(question)

    IO.puts("#{player_id}: answer: #{Enum.at(question.options, next_answer)}")

    Quiz.RoundServer.take_answer(state.round_id, player_id, next_answer)
    {:noreply, Map.put(state, :question, question)}
  end

  def handle_cast({:wrong_answer, player_id, correct_idx}, state) do
    IO.puts("#{player_id} got it wrong. Correct answer was #{Enum.at(state.question.options, correct_idx)}.")
    {:noreply, state}
  end

  def handle_cast({:correct_answer, player_id }, state) do
    IO.puts("#{player_id} got it right!")
    {:noreply, state}
  end

  def handle_cast({:won, player_id }, state) do
    IO.puts("#{player_id}: won")
    {:noreply, state}
  end

  def handle_cast({:lost, player_id }, state) do
    IO.puts("#{player_id}: lost")
    {:noreply, state}
  end
end


defmodule Demo.AutoPlayer do
  def next_answer(_question) do
    :timer.sleep(:rand.uniform(:timer.seconds(3)))
    :rand.uniform(4)-1
  end
end
