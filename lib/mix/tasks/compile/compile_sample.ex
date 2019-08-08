defmodule Mix.Tasks.Compile.CompileSample do
  use Mix.Task

  def run(_) do
    Mix.shell.cmd("make priv/libnif.so")
    :ok
  end
end