defmodule Hastega do
  import SumMag
  import Hastega.Util
  import Hastega.Parser
  require Hastega.Db
  import Hastega.Db


  import Hastega.Generator
  import SumMag

  alias Hastega.Generator
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
    functions
    |> optimize
    |> Opt.inspect(label: "OPTIMIZE")
  end

  # @spec optimize(AST.t()) :: AST.t()
  def optimize(functions) do
    functions
    |> replace_function_block
  end

  def replace_function_block(func_block) 
  when is_list(func_block) do
    func_block
    |> melt_block
    |> Enum.map(& &1 |> replae_function)
    |> iced_block
  end

  @doc """
        iex> 

  """
  def replae_function({:def, meta, [arg_info, process]}) do
    ret = process 
    |> melt_block
    # 式ごとに最適化を行う．パイプでつながったコードは１つの式として扱える
    |> Enum.map(&( 
        &1
        |> Opt.inspect(label: "original")
        |> Macro.unpipe
        |> Opt.inspect(label: "unpipe")
        # Future code
        # |> fusion_function

        |> to_nif

        |> pipe
      ))
    |> iced_block

    {:def, meta, [arg_info, ret]}
  end

  def replace_function(other), do: raise "syntax error"

  def to_nif(expr) when expr |> is_list do
    expr
    |> Opt.inspect(label: "to nif")
    |> Enum.map(& &1 |> replace_term)
  end

  def replace_term({{atom, _, nil}, _pos} = arg) 
    when atom |> is_atom do
     Opt.inspect("This is a variable")
     arg
  end

  def replace_term({quoted, position}) do
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
    [ret, nil] = ret |> Opt.inspect(label: "pipe")
    ret
  end
end

defmodule Hastega.Enum do
  import SumMag

  alias SumMag.Opt
  alias Hastega.Func

  def replace_expr({quoted, :map}) do
    Opt.inspect "Find Enum.map!"
    Opt.inspect "Try to replace code."
    
    # Enum.mapのASTが含む
    {_enum_map, _, anonymous_func} = quoted |> Opt.inspect(label: "input")

    anonymous_func
    |> Func.enabled_nif?
    |> Opt.inspect(label: "enabled?")
    |> call_nif(:map)
  end

  def replace_expr({quoted, :chunk_every}) do
    Opt.inspect "Find Enum.chunk_every"
    {_enum, _, num} = quoted |> Opt.inspect(label: "input")
    
    call_nif(num, :chunk_every)
  end

  def replace_expr({quoted, func}) do
    Opt.inspect "Sorry, not supported yet."
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
    Generator.register_enum_chunk_every(num)
  end

  def call_nif({:ok, asm}, :map) do
    %{operator: operator, left: left, right: right} = asm

  end
end

defmodule Hastega.Func do
  import SumMag
  alias SumMag.Opt

  def enabled_nif?([{:&, _, [1]}]) do
    Opt.inspect "This is captured val."
  end

  def enabled_nif?([{:&, _, other}]) do
    other
    |> basic_operator?
  end

  def enabled_nif?([{:fn, _, [->: [arg, expr]]}]) do
    expr
    |> basic_operator?
  end

  @doc """
  Returns Map for binomial expr.
  
        iex> (quote do: 1 + 2) |> basic_opetator?
        
  """
  # Anonymous functions with &
  def basic_operator?({:+, _, [left, right]} = ast) do
    Opt.inspect "This is basic operator :+, but not supported."
  end

  def basic_operator?([{:-, _, [left, right]}] = ast) do
    Opt.inspect "This is basic operator :+, but not supported."
  end

  def basic_operator?([{:*, _, [left, right]}] = ast) do
    ast 
    |> Opt.inspect(label: "This is basic operator :*. with &")

    if right |> quoted_var? && left |> quoted_var? do
      Opt.inspect "This is a binomial expression."
      {:ok, ast |> to_map}
    end
  end

  def basic_operator?({:/, _,[left, right]} = ast) do
    Opt.inspect "This is basic operator :+, but not supported."
  end

  # Anonymous functions with fn 
  def basic_operator?({:+, _,[left, right]} = ast) do
    Opt.inspect "This is basic operator :+, but not supported."
  end

  def basic_operator?({:-, _,[left, right]} = ast) do
    Opt.inspect "This is basic operator :+, but not supported."
  end

  def basic_operator?({:*, _,[left, right]} = ast) do
    ast 
    |> Opt.inspect(label: "This is basic operator :*. with fn")
    
    if right |> quoted_var? && left |> quoted_var? do
      Opt.inspect "This is a binomial expression."
      {:ok, ast |> to_map}
    end
  end

  def basic_operator?({:/, _,[left, right]} = ast) do
    Opt.inspect "This is basic operator :+, but not supported."
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