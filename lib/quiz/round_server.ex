defmodule Quiz.RoundServer do
  use GenServer

  alias Quiz.Round
  alias Quiz.PlayerNotifier

  require Logger

  @moduledoc """

  GenServer managing a single round.

  Creates the state for a new round using the `Round` module when it is started (init/1).
  The functions in round (start/1 and take_answer/2) return a list of instructions
  for the players. RoundServer uses PlayerNotifier to pass the instructions to the
  player-processes, which in turn use the API of round server to answer (take_answer/3).
  """

  @type id :: any
  @type player :: %{id: Round.player_id, callback_mod: module, callback_arg: callback_arg}
  @type callback_arg :: any

  ### API FUNCTIONS ###

  @spec take_answer(id, Round.player_id, 0..3) :: :ok
  @doc """
  API function that is used by the players (modules that implement the behaviour defined
  in PlayerNotifier).

  Receives an answer to the current question.
  """
  def take_answer(round_id, player_id, answer) do
    GenServer.call(service_name(round_id), {:take_answer, player_id, answer})
  end

  @doc ""
  def start_link(round_id, players) do
    GenServer.start_link(
      __MODULE__,
      { round_id, Enum.map(players, &(&1.id)) },
      name: service_name(round_id)
    )
  end

  ### CALLBACKS

  @doc false
  def init({round_id, player_ids}) do
    {:ok,
      player_ids
      |> Round.start()
      |> handle_round_result(%{round_id: round_id, round: nil}) # why round not passed here
    }
  end

  @doc false
  def handle_call({:take_answer, player_id, answer }, _from, state) do
      newstate = state.round
      |> Round.take_answer(player_id, answer)
      |> handle_round_result(state)

    {:reply, :ok, newstate }
  end

  ### Privates


  @doc "Returns a tuple to identify a round in the Quiz.Registry"
  defp service_name(round_id) do
    Quiz.service_name({__MODULE__, round_id})
  end

  defp handle_round_result({instructions, round}, state) do
    Enum.reduce(instructions, %{state|round: round}, &handle_instruction(&2, &1))
  end

  defp handle_instruction(state, {:notify_player, player_id, instruction}) do
    PlayerNotifier.publish(state.round_id, player_id, instruction)
    state
  end
end
