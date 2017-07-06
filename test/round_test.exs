defmodule Blackjack.RoundTest do
  use ExUnit.Case, async: true

  alias Quiz.Question
  alias Quiz.Round

  @questions [
      %Question{ text: "t", options: [ "a" ], solution: 0 },
      %Question{ text: "t2", options: [ "b" ], solution: 0 }
    ]

  test "start" do
    assert {instructions, round} = Round.start([:a, :b], @questions)
    assert instructions == [
      {:notify_player, :a, { :next_question, %{ text: "t", options: [ "a" ] }}},
      {:notify_player, :b, { :next_question, %{ text: "t", options: [ "a" ] }}}
    ]
    assert round == %Round{
      players: [:a, :b],
      questions: [%Question{ text: "t2", options: [ "b" ], solution: 0 }],
      done_questions: [],
      current_question:  %{answers: [], options: ["a"], solution: 0, text: "t"},
      instructions: []
    }
  end

  test "player gives wrong answer, gets notification with correct answer" do
    assert {_instructions, round} = Round.start([:a, :b], @questions)
    assert {instructions, _round } = Round.take_answer(round, :a, 1)
    assert instructions == [
      {:notify_player, :a, { :wrong_answer, 0 }},
    ]
  end

  test "player gives correct answer, gets notification" do
    assert {_instructions, round} = Round.start([:a, :b], @questions)
    assert {instructions, _round } = Round.take_answer(round, :a, 0)
    assert instructions == [
      {:notify_player, :a, { :correct_answer }},
    ]
  end

  test "both players answer, next question is presented" do
    assert {instructions, _round } = Round.start([:a, :b], @questions) |> rnd
    |> Round.take_answer(:a, 1) |> rnd
    |> Round.take_answer(:b, 0)

    assert instructions == [
      {:notify_player, :b, { :correct_answer }},
      {:notify_player, :a, { :next_question, %{ text: "t2", options: [ "b" ] }}},
      {:notify_player, :b, { :next_question, %{ text: "t2", options: [ "b" ] }}}
    ]
  end

  test "all questions are answered" do
    assert {instructions, _round } = Round.start([:a, :b], @questions) |> rnd
    |> Round.take_answer(:a, 1) |> rnd
    |> Round.take_answer(:b, 0) |> rnd
    |> Round.take_answer(:a, 1) |> rnd
    |> Round.take_answer(:b, 0)

    assert instructions == [
      {:notify_player, :b, { :correct_answer }},
      {:notify_player, :b, { :finish, :won }},
      {:notify_player, :a, { :finish, :lost }}
    ]
  end

  def rnd({_, round}), do: round
end
