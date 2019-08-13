defmodule HastegaBench do
  use Benchfella

  @list_0x100     (1..0x100) |> Enum.to_list
  @list_0x1000    (1..0x1000) |> Enum.to_list
  @list_0x10000   (1..0x10000) |> Enum.to_list
  @list_0x100000  (1..0x100000) |> Enum.to_list

  bench "Enum.map: 0x100 * 2" do
    Enum.map(@list_0x100, & &1 * 2)
  end

  bench "Hastega Enum.map: 0x100 * 2" do
    HastegaSample.list_mult_2(@list_0x100)
  end

  bench "Enum.map: 0x1000 * 2" do
    Enum.map(@list_0x1000, & &1 * 2)
  end

  bench "Hastega Enum.map: 0x1000 * 2" do
    HastegaSample.list_mult_2(@list_0x1000)
  end

  bench "Enum.map: 0x10000 * 2" do
    Enum.map(@list_0x10000, & &1 * 2)
  end

  bench "Hastega Enum.map: 0x10000 * 2" do
    HastegaSample.list_mult_2(@list_0x10000)
  end
end