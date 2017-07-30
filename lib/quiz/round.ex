defmodule Quiz.Round do
  defstruct [
    :questions, :players, :done_questions, :current_question, :instructions
  ]

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

  def start(player_ids) do
    start(player_ids, random_questions(4))
  end

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

  defp add_answer(%Round{current_question: %{ answers: answers }} = round, player_id, answer) do
    # TODO check if player has already answered and fail
    %Round{round|current_question: %{round.current_question|answers: [{player_id, answer}|answers]}}
  end

  defp answer_instruction(%Round{ current_question: %{ solution: solution }} = round, player_id, answer) when solution == answer do
    round |> notify_player(player_id, {:correct_answer})
    # TODO notify other player about this
  end

  defp answer_instruction(%Round{current_question: %{ solution: solution }} = round, player_id, answer) when solution != answer do
    round |> notify_player(player_id, {:wrong_answer, solution})
    # TODO notify other player about this
  end

  defp check_question_done(%Round{current_question: %{ answers: answers }} = round) when length(answers) == 2 do
    round
     |> question_done
     |> pop_question
  end

  defp check_question_done(round) do
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
    round
    |> take_instructions
  end

  # blows up when called with a Round with current_question defined
  defp pop_question(%Round{questions: [question|tail], current_question: nil} = round) do
    round
    |> Map.put(:current_question, Question.add_answers(question))
    |> Map.put(:questions, tail)
    |> send_question_to_players
  end

  defp pop_question(%Round{questions: [] } = round) do
    round
    |> finish_round
  end

  defp finish_round(%Round{questions: [] } = round) do
    results = sum_wins(round) |> get_winner_loser

    round
    |> add_finish_notifications(results)
  end

  defp add_finish_notifications(round, info) do
    round
    |> notify_player(elem(info.winner, 0), { :finish, :won })
    |> notify_player(elem(info.loser, 0), { :finish, :lost })
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

  def to_keyword_list(dict) do
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

  defp take_instructions(round) do
    {Enum.reverse(round.instructions), %Round{round | instructions: []}}
  end

  def random_questions(_) do
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
