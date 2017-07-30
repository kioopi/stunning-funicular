defmodule Quiz.RoundsSupervisor do
  import Supervisor.Spec

  @rounds_supervisor __MODULE__

  @spec child_spec() :: Supervisor.Spec.spec

  @doc """
  Returns a child spec to start a supervisor that will be responsible for
  holding processes based of this module.
  Used in the root-supervisor in Quiz.Application.

  Each child is in turn a supervisor that has a RoundServer and
  a PlayerNotifier.Supervisor.

  Children get started by Quiz.start_playing/2
  """
  def child_spec() do
    supervisor(
      Supervisor,
      [
        [supervisor(__MODULE__, [])],
        [strategy: :simple_one_for_one, name: @rounds_supervisor]
      ],
      id: @rounds_supervisor
    )
  end

  @doc """
  Starts a supervisor that hasa RoundServer and a PlayerNotifier.Supervisor
  as children.
  """
  def start_link(round_id, players) do
    children = [
      supervisor(Quiz.PlayerNotifier.Supervisor, [round_id, players]),
      worker(Quiz.RoundServer, [round_id, players])
    ]

    opts = [strategy: :one_for_all]

    Supervisor.start_link(children, opts)
  end
end
