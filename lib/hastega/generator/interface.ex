defmodule Hastega.Generator.Interface do
  import Hastega.Db

  alias Hastega.Db
  alias SumMag.Opt
  @nif_ex "lib/interact_nif.ex"

  def generate do
    funcs = generate_functions

    # funcs = funcs <> """
    # def add(_a, _b), do: raise "NIF add/2 not implemented"
    # """

    str = """  
    defmodule HastegaNif do
      @on_load :load_nifs

      def load_nifs do
        :erlang.load_nif('./priv/libnif', 0)
      end

    #{funcs}
    end
    """

    @nif_ex
    |> File.write(str)
  end

  defp generate_functions do
    Db.get_functions
    |> Opt.inspect(label: "DB")
    |> Enum.map(& &1 |> generate_function)
    |> List.to_string
  end

  defp generate_function([func_info]) do
    %{
      nif_name: nif_name,
      module: module,
      function: origin, 
      arg_num: num,
      args: args,
      operators: operators
    } = func_info

    args = generate_string_arguments(num)

    """
      def #{nif_name}(#{args}), do: raise "NIF #{nif_name}/#{num} not implemented"
    """
    |> Opt.inspect
  end

  defp generate_string_arguments(num) do
    (1..num)
    |> Enum.reduce(
      "", 
      fn
       x, "" -> "_arg#{x}"
       x, acc -> acc <> ", _arg#{x}"
      end)
  end
end