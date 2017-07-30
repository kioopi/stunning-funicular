defmodule Quiz.Round do
  defstruct [
    :questions, :players, :done_questions, :current_question, :instructions
  ]

  @moduledoc """
  Contains functions to handle the state of a round.
  This state happens to be in the shape of the struct defined above.

  `start/1 or 2` creates the state for a round that is stored in RoundServer.
  This state includes a list of instructions that notifies the players about
  in the state of the round.

  `take_answer/3` updates a round/instructions according to a guess by a player.
  """

  require Logger

  alias Quiz.Question
  alias Quiz.Round

  @type t :: %Round{
    questions: [Question.t],
    current_question: Question.with_answers,
    players: [player_id],
    done_questions: [Question.with_answers],
    instructions: [instruction]
  }

  @type instruction :: {:notify_player, player_id, player_instruction }

  @type player_instruction ::
    {:next_question, Question.without_solution} |
    {:wrong_answer, 0..3} |
    :correct_answer |
    {:finish, :won } |
    {:finish, :lost} |
    :timeout

  @type player_id :: any
  @type move :: { :solve, 0..3 }
  @type answer :: { player_id, 0..3 }

  @spec start([player_id]) :: {[instruction], t}

  ### PUBLIC

  def start(player_ids) do
    start(player_ids, random_questions(4))
  end

  @doc """
  Creates the inital state for a round and the first list of player instructions.
  """
  def start(player_ids, questions) do
    %Round{
      questions: questions,
      players: player_ids,
      instructions: [],
      done_questions: []
    }
    |> pop_question
    |> instructions_and_state
  end

  def take_answer(round, player_id, answer) do
    round
    |> add_answer(player_id, answer)
    |> answer_instruction(player_id, answer)
    |> check_question_done
    |> instructions_and_state
  end

  ### PRIVATES

  # @doc "Just logs an answer."
  defp add_answer(%Round{current_question: %{ answers: answers }} = round, player_id, answer) do
    # TODO check if player has already answered and fail
    %Round{round|current_question: %{round.current_question|answers: [{player_id, answer}|answers]}}
  end

  # @doc "Creates a notification informing the player whether `answer` was correct adding the correct answer if it wasn't"
  defp answer_instruction(%Round{ current_question: %{ solution: solution }} = round, player_id, answer) when solution == answer do
    round |> notify_player(player_id, {:correct_answer})
    # TODO notify other player about this
  end

  defp answer_instruction(%Round{current_question: %{ solution: solution }} = round, player_id, answer) when solution != answer do
    round |> notify_player(player_id, {:wrong_answer, solution})
    # TODO notify other player about this
  end

  defp check_question_done(%Round{current_question: %{ answers: answers }, players: players} = round) when length(answers) == length(players) do
    Logger.debug("Question so done ------")
    round
     |> question_done
     |> pop_question
  end

  defp check_question_done(round) do
    Logger.debug("Question not done")
    Logger.debug(inspect round.current_question.answers)
    round
  end

  defp question_done(%Round{ current_question: current_question }) when is_nil(current_question) do
    Logger.debug("Should not be here")
    { :error, :invalid_state }
  end

  defp question_done(%Round{ current_question: current_question, done_questions: done_questions }=round) do
    round
    |> Map.put(:current_question, nil)
    |> Map.put(:done_questions, [current_question|done_questions])
  end

  defp instructions_and_state(round) do
    {Enum.reverse(round.instructions), %Round{round | instructions: []}}
  end

  # Moves a question from the backlog (questions) to the current_question slot.
  # Will blow up when called with a Round with current_question defined.
  defp pop_question(%Round{questions: [question|tail], current_question: nil} = round) do
    round
    |> Map.put(:current_question, Question.add_answers(question))
    |> Map.put(:questions, tail)
    |> send_question_to_players
  end

  # When called on  a round with no more items in `questions` calls `finish_round/1` to
  # kupdate the state/instructions to determines a winner.
  defp pop_question(%Round{questions: [] } = round) do
    round
    |> finish_round
  end

  defp finish_round(%Round{questions: [] } = round) do
    results = sum_wins(round) |> get_winner_loser

    round
    |> add_finish_notifications(results)
  end

  defp get_winner_loser(data) do
    ordered =  List.keysort(data, 1) |> Enum.reverse()
    %{
      winner: List.first(ordered),
      loser: List.last(ordered)
    }
  end

  defp sum_wins(%Round{questions: [], current_question: nil, done_questions: done_questions }) do
    cb = fn(q, acc) -> sum_wins_question(acc, q.answers, q.solution) end
    Enum.reduce(done_questions, %{}, cb) |> to_keyword_list
  end

  defp sum_wins_question(acc, answers, solution) do
    checker = fn
      answer when answer == solution -> 1
      answer when answer != solution -> 0
    end

    Enum.reduce(answers, acc, fn({user, answer}, acc) -> Map.update(acc, user, checker.(answer), fn(score) -> checker.(answer) + score end) end)
  end

  defp add_finish_notifications(round, info) do
    round
    |> notify_player(elem(info.winner, 0), { :finish, :won })
    |> notify_player(elem(info.loser, 0), { :finish, :lost })
  end

  defp to_keyword_list(dict) do
      Enum.map(dict, fn({key, value}) -> {key, value} end)
  end

  defp send_question_to_players(round) do
    question = round.current_question
    round
    |> notify_player(first_player(round), { :next_question, Question.remove_solution(question) })
    |> notify_player(second_player(round), { :next_question, Question.remove_solution(question) })
  end

  defp first_player(%Round{ players: players }) do
    List.first(players)
  end

  defp second_player(%Round{ players: players }) do
    List.last(players)
  end

  defp notify_player(round, player_id, data) do
    add_instruction(round, {:notify_player, player_id, data})
  end

  defp add_instruction(round, instruction) do
    %Round{ round|instructions: [instruction|round.instructions]}
  end

  defp random_questions(_) do
    [
      %Question{
        text: "Wo finden die Olympischen Winterspiele 2010 statt?",
        options: [
          "Vancouver (Kanada)",
          "Stockholm (Schweden)",
          "Sotschi (Russland)",
          "Athen (Griechenland)"
        ],
        solution: 0
      },
      %Question{
        text: "Nach wie vielen Fouls muss ein Basketballspieler vom Feld?",
        options: [ "4", "5", "6", "7" ],
        solution: 1
      },
      %Question{
        text: "Wie viele Minuten dauert eine Halbzeit beim Handball?",
        options: [ "10", "20", "25", "30" ],
        solution: 3
      },
      %Question{
        text: "Wie viele Tennisspieler stehen bei einem Doppel auf dem Platz?",
        options: [ "2", "4", "6", "8" ],
        solution: 1
      },
    ]
  end
end
