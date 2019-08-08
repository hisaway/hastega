defmodule Hastega.Db do
  # @on_load :init
  @table_name :nif_func

  alias SumMag.Opt

  @moduledoc """
  Documentation for Hastega.Generator.
  """
  def init do
    @table_name
    |> :ets.new([:set, :public, :named_table])

    @table_name
    |> :ets.insert({:id, 1})
  end

  def register(info) when 
    info |> is_map do

    # id = get_id |> to_string

    info = generate_string_function_name(info)

    @table_name
    |> :ets.insert({:function, info})
  end

  def get_functions do
    @table_name
    |> :ets.match({:function, :"$1"})
  end
  
  defp get_id do
    [id: num] = @table_name |> :ets.lookup(:id)

    update_id(num)

    num
  end

  defp update_id(id) do
    @table_name |> :ets.insert({:id, id+1})
  end 

  defp generate_string_function_name(info) do
     %{
      module: module,
      function: func_name,
      arg_num: num,
      args: args,
      operators: operators
    } = info

    ret = operators
    |> Enum.map(& &1 |> operator_to_string)
    |> Enum.reduce("", fn x, acc -> acc <> "_#{x}" end)

    str = Atom.to_string(func_name)

    info |> Map.put_new(:nif_name, str <> ret)
  end

  defp operator_to_string(operator)
    when operator |> is_atom do
      case operator do
        :* -> "mult"
        :+ -> "plus"
        :- -> "minus"
        :/ -> "div"
      end
  end

  # def on_load do
  #   case :mnesia.start do
  #     :ok -> case :mnesia.create_table( :functions, [ attributes: [ :id, :module_name, :function_name, :is_public, :is_nif, :args, :do ] ] ) do
  #       {:atomic, :ok} -> :ok
  #       _ -> :err
  #     end
  #     _ -> :err
  #   end
  # end

  # def write_function({key, value}, module) do
  #   :mnesia.dirty_write({
  #     :functions,
  #     key,
  #     module,
  #     value[:function_name],
  #     value[:is_public],
  #     value[:is_nif],
  #     value[:args],
  #     value[:do]})
  # end

  # def read_function(id) do
  #   :mnesia.dirty_read({:functions, id})
  # end

  # def all_functions() do
  #   :mnesia.dirty_all_keys(:functions)
  # end

end