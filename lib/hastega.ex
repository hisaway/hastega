defmodule Hastega do
  import SumMag
  import Hastega.Util
  import Hastega.Parser
  import Hastega.Db
  import Hastega.Generator
  import SumMag

  alias Hastega.Generator
  alias Hastega.Db
  alias Hastega.Func
  alias SumMag.Opt

  @moduledoc """
  ## Hastega: Hyper Accelerator of Spreading Tasks for Elixir with GPU Activation

  For example, the following code of the function `map_square` will be compiled to native code using SIMD instructions by Hastega.

  ```elixir
  defmodule M do
    require Hastega
    import Hastega

    defhastega do
      def map_square (list) do
        list
        |> Enum.map(& &1 * &1)
      end

      hastegastub
    end
  ```
  """
  defmacro defhastega(functions) do
    Db.init

    ret = functions
    |> SumMag.map(&replace_function/1)

    hastegastub

    ret
  end

  def hastegastub do
    # all_functions()
    # |> Enum.map(& hd(read_function(&1)))
    # |> Enum.map(& Hastega.Generator.generate_nif(&1))
    # |> IO.inspect

    Generator.generate

    # quote do end
  end

  @doc """
        iex> 

  """
  def replace_function({:def, meta, [arg_info, process]}) do
    ret = process 
    |> SumMag.map(& native/1)

    {:def, meta, [arg_info, ret]}
  end

  def replace_function(other), do: raise "syntax error"

  defp native(expr) when is_tuple(expr) do
    expr
    |> Macro.unpipe
    |> to_nif
    
    # Future code
    # |> fusion_function
    
    |> pipe
  end

  def to_nif(expr) when is_list(expr) do
    expr
    |> Opt.inspect(label: "to nif")
    |> Enum.map(& &1 |> replace_term)
  end

  defp replace_term({{atom, _, nil}, _pos} = arg) 
    when atom |> is_atom do
     # Opt.inspect("This is a variable")
     arg
  end

  defp replace_term({quoted, position}) do
    ret = quoted
    |> Hastega.Enum.replace_expr

    {ret, position}
  end

  defp pipe(unpipe_list) do
    pipe_meta = [context: Elixir, import: Kernel]

    {arg, 0} = hd unpipe_list
    func = tl unpipe_list

    acc = {:|>, [], [arg, nil] }

    {:|>, [], ret} = func
    |> Enum.reduce(acc, 
      fn x, acc -> 
        {func, 0} = x

        acc
        |> Macro.prewalk( fn 
          {:|>, [], [left, nil]} -> {:|>, [], [{:|>, pipe_meta, [left, func]}, nil]}
          other -> other
        end)
      end)
    [ret, nil] = ret 
    # |> Opt.inspect(label: "pipe")
    
    ret
  end
end

defmodule Hastega.Enum do

  import SumMag
  import Hastega.Db

  alias Hastega.Db
  alias SumMag.Opt
  alias Hastega.Func

  def replace_expr({quoted, :map}) do
    Opt.inspect "Find Enum.map!"
    Opt.inspect "Try to replace code."
    
    # Enum.mapのASTが含む
    {_enum_map, _, anonymous_func} = quoted |> Opt.inspect(label: "input")

    anonymous_func
    |> Func.enabled_nif?
    # |> Opt.inspect(label: "enabled?")
    |> call_nif(:map)
  end

  def replace_expr({quoted, :chunk_every}) do
    Opt.inspect "Find Enum.chunk_every"
    {_enum, _, num} = quoted |> Opt.inspect(label: "input")
    
    call_nif(num, :chunk_every)
  end

  def replace_expr({quoted, func}) do
    str = Macro.to_string(quoted)

    Opt.inspect "Sorry, #{str} not supported yet."
    quoted
  end

  def replace_expr(other) do
    other
    |> which_enum_func?
    |> replace_expr
  end

  defp which_enum_func?(ast) do
    {_, flag} = Macro.prewalk(ast, false,
      fn 
      ({:__aliases__, _,[:Enum]} = ast, acc) -> {ast, true}
      (other, acc) -> {other, acc}
      end)

    case flag do
      true -> {ast, ast |> which_function?}
      false -> {ast, nil}
    end
  end

  defp which_function?(ast) do
    {_, func} = Macro.prewalk(ast, false,
      fn 
      (:map = ast, acc) -> {ast, :map}
      (:chunk_every = ast, acc) ->{ast, :chunk_every}
      (other, acc) -> {other, acc}
      end)

    func
  end

  def call_nif(num, :chunk_every) do
    quote do: HastegaNif.chunk_every(4)
  end

  def call_nif({:ok, asm}, :map) do
    %{
        operator: operator,
        left: left,
        right: right
      } = asm

    func_name = generate_function_name(:map, [operator])

    # plan to fix this data
    info = %{
      module: :enum,
      function: :map,
      nif_name: func_name,
      arg_num: 1,
      args: [left, right], 
      operators: [operator]
    }

    Db.register(info)

    func_name = func_name |> String.to_atom

    quote do: HastegaNif.unquote(func_name)
  end

  defp generate_function_name(func, operator) do
    ret = operator
    |> Enum.map(& &1 |> operator_to_string)
    |> Enum.reduce("", fn x, acc -> acc <> "_#{x}" end)

    Atom.to_string(func) <> ret
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
end

defmodule Hastega.Func do
  import SumMag
  alias SumMag.Opt

  defmodule Env do
    defstruct operator: [:+, :-, :*, :/]
  end

  defp supported_operator?(atom) when is_atom(atom) do
    %Hastega.Func.Env{}.operator
    |> Enum.find_value(fn x -> x == atom end)
    |> IO.inspect
  end

  def enabled_nif?([{:&, _, [1]}]) do
    Opt.inspect "This is captured val."
  end

  def enabled_nif?([{:&, _, other}]) do
    other
    |> supported?
  end

  def enabled_nif?([{:fn, _, [{:->, _, [arg, expr]}]}]) do
    expr
    |> supported?
  end

  @doc """
  Returns Map for binomial expr.
  
        iex> (quote do: 1 + 2) |> basic_opetator?
        
  """
  # Anonymous functions with &
  def supported?([{atom, _, [left, right]}] = ast) do
    if supported_operator?(atom) && quoted_vars?(left, right) do
      {:ok, ast |> to_map}
    else
      {:error, ast}
    end
  end

  # Anonymous functions with fn 
  def supported?({atom, _,[left, right]} = ast) do
    if supported_operator?(atom) && quoted_vars?(left, right) do
      {:ok, ast |> to_map}
    else
      {:error, ast}
    end
  end

  defp to_map({atom, _, [left, right]}) do
    %{
        operator: atom,
        left: left,
        right: right
      }
  end

  defp to_map([{atom, _, [left, right]}]) do
    %{
        operator: atom,
        left: left,
        right: right
      }
  end
end