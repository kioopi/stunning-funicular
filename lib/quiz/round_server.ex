defmodule Quiz.RoundServer do
  use GenServer

  import Supervisor.Spec # functions to define how to run a supervisor
  alias Quiz.Round
  alias Quiz.PlayerNotifier

  require Logger

  @moduledoc """
  This contains the child_spec for a supervisor that gets in the root supervisor.
  This supervisor holds instances of this module, Quiz.Roundserver.
  They get started by the function start_playing.
  So every round has its own RoundServer, which holds the Round in its state.

  When a start_playing is called with a round_id (pid or identifier of roundserver)
  and two players (tuple describing how to contact module that implents PlayerNotifier behaviour),
  a new supervisor is started as a child of @rounds_supervisor.
  This supervisor contains a PlayerNotifier process and a RoundServer process.

  The RoundServer will (in the start_link and init functions that get called automatically)
  create the state that is used by the functions in the Round module.
  """

  # seems to be just a name given to the supervisor
  # so it doesn't have to be refered to by pid
  @rounds_supervisor Quiz.RoundSup

  @type id :: any
  @type player :: %{id: Round.player_id, callback_mod: module, callback_arg: callback_arg}
  @type callback_arg :: any

  @spec child_spec() :: Supervisor.Spec.spec

  @doc """
    Returns a child spec to start a supervisor that will be responsible for
    holding processes based of this module.
  """
  def child_spec() do
    Supervisor.Spec.supervisor(
      Supervisor,
      [
        [Supervisor.Spec.supervisor(__MODULE__, [], function: :start_supervisor)],
        [strategy: :simple_one_for_one, name: @rounds_supervisor]
      ],
      id: @rounds_supervisor
    )
  end

  @doc """
  Starts a new process of RoundServer in the @rounds_supervisor
  This will call RoundServer.start_link.
  """
  @spec start_playing(id, [player]) :: Supervisor.on_start_child
  def start_playing(round_id, players) do
    Supervisor.start_child(@rounds_supervisor, [round_id, players])
  end

  @doc """
  API function that is used by the players.
  """
  @spec take_answer(id, Round.player_id, 0..3) :: :ok
  def take_answer(round_id, player_id, answer) do
    GenServer.call(service_name(round_id), {:take_answer, player_id, answer})
  end

  @doc """
  Callback to call instead of start_link when this module is started
  as a supervisor.

  So this module cann be started as a supervisor as well as as worker.
  """
  def start_supervisor(round_id, players) do
    Supervisor.start_link(
      [
        PlayerNotifier.child_spec(round_id, players),
        worker(__MODULE__, [round_id, players])
      ],
      strategy: :one_for_all
    )
  end

  @doc false
  def start_link(round_id, players) do
    GenServer.start_link(
      __MODULE__,
      { round_id, Enum.map(players, &(&1.id)) },
      name: service_name(round_id)
    )
  end

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
      Logger.debug("Round server :take_answer #{player_id} #{state.round.current_question.text} #{answer} ")
      newstate = state.round
      |> Round.take_answer(player_id, answer)
      |> handle_round_result(state)

    {:reply, :ok, newstate }
  end

  defp service_name(round_id) do
    Quiz.service_name({__MODULE__, round_id})
  end

  defp handle_round_result({instructions, round}, state) do
    Enum.reduce(instructions, %{state|round: round}, &handle_instruction(&2, &1))
  end

  defp handle_instruction(state, {:notify_player, player_id, instruction}) do
    Logger.debug("Send instruction to #{player_id} #{inspect instruction}")
    PlayerNotifier.publish(state.round_id, player_id, instruction)
    state
  end
end
