defmodule Quiz.Question do
  defstruct [:text, :options, :solution]


  @moduledoc """
  Represents a single question. Text, an array of possible answers (options)
  and the index of the correct option (0..3).

  There are different variants of a question:
   Quiz.Question.t -> has all info.
   Quiz.Question.without_solution -> does not contain info about which option is correct.  This is sent to the players.
   Quiz.Question.with_answers -> contains an array with the guesses of the players:  {player_id, index}
  """

  @type t :: %Quiz.Question{
    text: String.t,
    options: [String.t],
    solution: 0..3
  }

  @type without_solution :: %{
    text: String.t,
    options: [String.t],
  }

  @type with_answers :: %{
    text: String.t,
    options: [String.t],
    answers: [answer]
  }

  @spec remove_solution(t) :: without_solution
  def remove_solution(question) do
    %{
      text: question.text,
      options: question.options
    }
  end

  @spec add_answers(t) :: with_answers
  def add_answers(question) do
    %{
      text: question.text,
      options: question.options,
      solution: question.solution,
      answers: []
    }
  end

  @type answer :: { any, 0..3 }
end
