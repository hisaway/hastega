defmodule Hastega.Generator do
  import Hastega.Db
  import Hastega.Generator.Interface

  alias Hastega.Db
  alias SumMag.Opt
  alias Hastega.Generator.Interface
  alias Hastega.Generator.Native

  def generate do
    Interface.generate
    Native.generate
  end
end