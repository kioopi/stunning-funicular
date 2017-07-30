defmodule Quiz.PlayerNotifier do
  use GenServer

  @moduledoc """
  This contains the child spec to run a supervisor to hold the processes
  based of PlayerNotifier.
  For every player_id one PlayerNotifier process is created.

  The api function `publish` decides which PlayerNotifier 

  """

  alias Quiz.{Round, RoundServer, Question}

  @callback next_question(RoundServer.callback_arg, Round.player_id, Question.without_solution) :: any
  @callback wrong_answer(RoundServer.callback_arg, Round.player_id, 0..3) :: any
  @callback correct_answer(RoundServer.callback_arg, Round.player_id) :: any
  @callback won(RoundServer.callback_arg, Round.player_id) :: any
  @callback lost(RoundServer.callback_arg, Round.player_id) :: any

  @spec child_spec(RoundServer.id, [RoundServer.player]) :: Supervisor.Spec.spec
  @doc """
  Returns a child_spec 
  """
  def child_spec(round_id, players) do
    import Supervisor.Spec

    supervisor(
      Supervisor,
      [
        Enum.map(players, &worker(__MODULE__, [round_id, &1], [id: {__MODULE__, &1.id}])),
        [strategy: :one_for_one]
      ]
    )
  end

  @spec publish(RoundServer.id, Round.player_id, Round.player_instruction) :: :ok
  def publish(round_id, player_id, player_instruction) do
    GenServer.cast(service_name(round_id, player_id), {:notify, player_instruction})
  end

  @doc false
  def start_link(round_id, player) do
    GenServer.start_link(
      __MODULE__,
      { round_id, player },
      name: service_name(round_id, player.id)
    )
  end

  @doc false
  def init({round_id, player}) do
    {:ok, %{round_id: round_id, player: player }}
  end

  @doc false
  def handle_cast({:notify, player_instruction}, state) do
    {fun, args} = decode_instruction(player_instruction)
    all_args = [state.player.callback_arg, state.player.id | args]
    apply(state.player.callback_mod, fun, all_args)

    {:noreply, state}
  end

  defp service_name(round_id, player_id) do
    Quiz.service_name({__MODULE__, round_id, player_id})
  end

  defp decode_instruction({:next_question, question}), do:
    { :next_question, [question] }
  defp decode_instruction({:wrong_answer, idx}), do: { :wrong_answer, [idx] }
  defp decode_instruction({:correct_answer}), do: { :correct_answer, [] }
  defp decode_instruction({:finish, :won}), do: { :won, [] }
  defp decode_instruction({:finish, :lost}), do: { :lost, [] }
end
