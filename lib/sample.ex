defmodule HastegaSample do
  import Hastega
  require Hastega

  defhastega do
    def cal(list) do
      list
      |> Enum.map(& &1 + 2)
      |> Enum.map(fn x -> x * 2 end)
    end

    def chunk_every(list) do
      list
      |> Enum.chunk_every(4)
    end
  end
end