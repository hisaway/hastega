defmodule HastegaNif do
  @on_load :load_nifs

  def load_nifs do
    :erlang.load_nif('./priv/libnif', 0)
  end

  def map_mult(_arg1, _arg2), do: raise "NIF map_mult/2 not implemented"

end
