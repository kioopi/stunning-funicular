defmodule Quiz do
  @moduledoc """
  Documentation for Quiz.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Quiz.hello
      :world

  """
  def service_name(service_id) do
    {:via, Registry, {Quiz.Registry, service_id}}
  end
end
