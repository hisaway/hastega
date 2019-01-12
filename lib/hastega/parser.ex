defmodule Hastega.Parser do

  @moduledoc """
  Documentation for Hastega.Parser.
  """

  @doc """
  		## Examples
  		iex> quote do end |> Hastega.Parser.parse(%{target: :hastega})
  		[]

  		iex> (quote do: def func(a), do: a) |> Hastega.Parser.parse(%{target: :hastega})
  		[[function_name: :func, is_public: true, args: [:a], do: [{:a, [], Hastega.ParserTest}], is_nif: false ]]

  		iex> (quote do
  		...>   def func(a), do: funcp(a)
  		...>   defp funcp(a), do: a
  		...> end) |> Hastega.Parser.parse(%{target: :hastega})
  		[[function_name: :func, is_public: true, args: [:a], do: [{:funcp, [], [{:a, [], Hastega.ParserTest}]}], is_nif: false ], [function_name: :funcp, is_public: false, args: [:a], do: [{:a, [], Hastega.ParserTest}], is_nif: false ]]

      iex> (quote do
      ...>    def func(list) do
      ...>      list
      ...>      |> Enum.map(& &1)
      ...>    end
      ...> end) |> Hastega.Parser.parse(%{target: :hastega})
      [[function_name: :func, is_public: true, args: [:list], do: [{:|>, [context: Hastega.ParserTest, import: Kernel], [{:list, [], Hastega.ParserTest}, {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [], [{:&, [], [{:&, [], [1]}]}]}]}], is_nif: false ]]
  """
  def parse({:hastegastub, _e, nil}, _env) do
    [:ignore_parse]
  end

  def parse({:def, e, body}, env) do
    env = Map.put_new(env, :num, 0)
    env = Map.put(env, :num, SumMag.increment_nif(env))
    parse_nifs(body, env)
    SumMag.parse({:def, e, body}, env)
  end

  def parse({:defp, e, body}, env) do
    env = Map.put_new(env, :num, 0)
    env = Map.put(env, :num, SumMag.increment_nif(env))
    parse_nifs(body, env)
    SumMag.parse({:defp, e, body}, env)
  end

  def parse({:__block__, _e, []}, _env), do: []

  def parse({:__block__, _e, body_list}, env) do
  	body_list
  	|> Enum.map(& &1
  		|> parse(env)
  		|> hd() )
  	|> Enum.reject(& &1 == :ignore_parse)
  end


  defp parse_nifs(body, env) do
    body
    |> tl
    |> hd
    |> hd
    |> parse_nifs_do_block(
      [function_name: (SumMag.parse_function_name(body, env)
        |> SumMag.concat_name_nif(env) ),
        is_public: true,
        is_nif: true],
      env)
  end

  defp parse_nifs_do_block({:do, do_body}, kl, env), do: parse_nifs_do_body(do_body, kl, env)

  defp parse_nifs_do_body({:__block__, _e, []}, _kl, _env), do: []

  defp parse_nifs_do_body({:__block__, _e, body_list}, kl, env) do
    body_list
    |> Enum.map(& &1
      |> parse_nifs_do_body(kl, env)
      |> hd() )
  end

  # match `p |> Enum.map(body)`
  defp parse_nifs_do_body({:|>, _e1, [p, {{:., _e2, [{:__aliases__, _e3, [:Enum]}, :map]}, _e4, body}]}, kl, env) do
    env = Map.put(env, :nif, func_with_num(kl, env))
    parse_enum_map(p, body, kl, env)
  end

  defp parse_nifs_do_body(value, _kl, _env) do
    [value]
  end

  def parse_enum_map({:|>, _e1, [p, {{:., _e2, [{:__aliases__, _e3, [:Enum]}, :map]}, _e4, body}]}, calling, kl, env) do
    {p_body, kl, env} = parse_enum_map(p, body, kl, env)
    IO.puts "p_body:"
    IO.inspect p_body
    IO.puts "body:"
    IO.inspect body
    IO.puts "calling:"
    IO.inspect calling
    IO.puts "kl:"
    IO.inspect kl
    ret = p_body ++ calling
    env = merge_func_info(env, [do: ret])
    IO.puts "env:"
    IO.inspect env
    IO.puts "ret:"
    IO.inspect ret
    {ret, kl, env}
  end

  def parse_enum_map(previous, calling, kl, env) do
    IO.puts "previous:"
    IO.inspect previous
    IO.puts "calling:"
    IO.inspect calling
    IO.puts "kl:"
    IO.inspect kl
    ret = [previous] ++ calling
    env = merge_func_info(env, [do: ret])
    IO.puts "env:"
    IO.inspect env
    IO.puts "ret:"
    IO.inspect ret
    {ret, kl, env}
  end

  @doc """
    ## Examples

    iex> [{:list, [line: 6], nil}, {:&, [line: 7], [{:&, [line: 7], [1]}]}] |> Hastega.Parser.create_pipe()
    {:|>, [context: Elixir, import: Kernel], [{:list, [line: 6], nil}, {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [], [{:&, [line: 7], [{:&, [line: 7], [1]}]}]}]}

    iex> [{:list, [line: 6], nil}, {:&, [line: 7], [{:&, [line: 7], [1]}]}, {:&, [line: 8], [{:&, [line: 8], [1]}]}] |> Hastega.Parser.create_pipe()
    {:|>, [context: Elixir, import: Kernel], [{:|>, [context: Elixir, import: Kernel], [{:list, [line: 6], nil}, {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [], [{:&, [line: 7], [{:&, [line: 7], [1]}]}]}
    ]}, {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [], [{:&, [line: 8], [{:&, [line: 8], [1]}]}]}]}
  """
  def create_pipe([a, b]) do
    {:|>, [context: Elixir, import: Kernel], [
      a,
      create_enum_map(b)
    ]}
  end
  def create_pipe([a, b | tail]) do
    {:|>, [context: Elixir, import: Kernel],
      [{:|>, [context: Elixir, import: Kernel], [
        a,
        create_enum_map(b)
      ]}, create_pipe(tail)]}
  end
  def create_pipe([a]), do: create_enum_map(a)

  @doc """
    ## Examples

    iex> {:&, [line: 7], [{:&, [line: 7], [1]}]} |> Hastega.Parser.create_enum_map()
    {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [], [{:&, [line: 7], [{:&, [line: 7], [1]}]}]}

    iex> [{:&, [line: 7], [{:&, [line: 7], [1]}]}] |> Hastega.Parser.create_enum_map()
    {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]}, [], [{:&, [line: 7], [{:&, [line: 7], [1]}]}]}
  """
  def create_enum_map([func]) do
    create_enum_map(func)
  end
  def create_enum_map(func) do
    {{:., [], [{:__aliases__, [alias: false], [:Enum]}, :map]},
     [],
     [func]}
  end

  @doc """
    ## Examples

    iex> Hastega.Parser.func_with_num([function_name: :func], %{num: 1})
    [function_name: :func_1]
  """
  def func_with_num(kl, env) do
    Keyword.put(kl, :function_name, (kl[:function_name] |> SumMag.concat_name_num(env)))
  end

  @doc """
    ## Examples

    iex> Hastega.Parser.get_func_info(%{nif: [function_name: :func]})
    [function_name: :func]
  """
  def get_func_info(%{nif: func_info}), do: func_info

  @doc """
    ## Examples

    iex> Hastega.Parser.merge_func_info(%{nif: [function_name: :func]}, [is_public: true])
    %{nif: [function_name: :func, is_public: true]}
  """
  def merge_func_info(env, keyword) do
    Map.put(env, :nif, Keyword.merge(get_func_info(env), keyword))
  end

end