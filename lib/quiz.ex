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
end
