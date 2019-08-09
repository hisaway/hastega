defmodule HastegaSample do
  import Hastega
  require Hastega

  @moduledoc """
  ```elixir
  defhastega do
    def cal(list) do
      list
      |> Enum.map(& &1 + 2)
    |> Enum.map(fn x -> x * 2 end)
  end
  
  #=>
  def cal(list) do
    list
    |> HastegaNif.map_mult
    |> HasegaNif.map_plus
  end
  ```
  """
  defhastega do
    def list_mult_2(list) do
      list
      |> Enum.map(fn x -> x * 2 end)
    end

    def list_plus_2(list) do
      list
      |> Enum.map(fn x -> x + 2 end)
    end

    # def chunk_every(list) do
    #   list
    #   |> Enum.chunk_every(4)
    # end
  end
end