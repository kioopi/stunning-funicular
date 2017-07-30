defmodule Quiz do
  @moduledoc """
  Documentation for Quiz.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Quiz.service_name(:x)
      {:via, Registry, {Quiz.Registry, :x }}

  """
  def service_name(service_id) do
    {:via, Registry, {Quiz.Registry, service_id}}
  end

  @doc """
  Starts a new child of RoundsSupervisor.
  (which in turn starts a RoundServer and a PlayerNotifier.Supervisor).
  """
  @spec start_playing(Quiz.RoundServer.id, [Quiz.RoundServer.player]) :: Supervisor.on_start_child
  def start_playing(round_id, players) do
    Supervisor.start_child(Quiz.RoundsSupervisor, [round_id, players])
  end
end
