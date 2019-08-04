defmodule Hastega.Generator do
  alias SumMag.Opt

  @table_name :nif_register
  @nif_ex "nif.ex"
  @nif_c "native/lib.c"

  @moduledoc """
  Documentation for Hastega.Generator.
  """
  def init do
    @table_name
    |> :ets.new([:set, :public, :named_table])

    File.open("lib/nif.ex")
  end

  def register(enum_func, option) when 
    enum_func |> is_bitstring and
    option |> is_list do

    @table_name
    |> :ets.insert({enum_func, option})
  end

  def generate_nif do
  	File.mkdir("native")

    str = """
    defmodule HastegaNif do
      @on_load :load_nifs

      def load_nifs do
        :erlang.load_nif('./priv/libnif', 0)
      end

      def add(_a, _b), do: raise "NIF add/2 not implemented"
    end
    """

    @nif_ex
    |> File.write(str)

    @nif_c
    |> File.write(init_nif)
  end

  def register_enum_chunk_every(num) do
    num |> Opt.inspect(label: "num:")

    option = hd(num) |> to_string

    register("enum_chunk_every", num)
    |> Opt.inspect(label: "REGISTERD FUNCTION")

    quote do: VecSample.chunk_every(4)
  end

  def register_enum_map_for_binomial_expr(operator, left, right) do
    quote do: VecSample.enum_map_mult_2
  end

  defp chunk_every(num) do

  end

  defp init_nif do
    """
    #include<stdbool.h>
    #include<erl_nif.h>
    const int fail = 0;
    const int success = 1;
    const int empty = 0;

    static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info);
    static void unload(ErlNifEnv *env, void *priv);
    static int reload(ErlNifEnv *env, void **priv, ERL_NIF_TERM info);
    static int upgrade(ErlNifEnv *env, void **priv, void **old_priv, ERL_NIF_TERM info);

    static
    ErlNifFunc nif_funcs[] =
    {
      // {erl_function_name, erl_function_arity, c_function}
      {"add", 2, add},
    };

    static ERL_NIF_TERM
    add(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
    {
      if (__builtin_expect((argc != 2), false)) {
        return enif_make_badarg(env);
      }
      long v1, v2;
      if (__builtin_expect((enif_get_int64(env, argv[0], &v1) == fail), false)) {
        return enif_make_badarg(env);
      }
      if (__builtin_expect((enif_get_int64(env, argv[1], &v2) == fail), false)) {
        return enif_make_badarg(env);
      }
      return enif_make_int64(env, v1 + v2);
    }

    static int
    load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info)
    {
      return 0;
    }

    static void
    unload(ErlNifEnv *env, void *priv)
    {
    }

    static int
    reload(ErlNifEnv *env, void **priv, ERL_NIF_TERM info)
    {
      return 0;
    }

    static int
    upgrade(ErlNifEnv *env, void **priv, void **old_priv, ERL_NIF_TERM info)
    {
      return load(env, priv, info);
    }

    ERL_NIF_INIT(Elixir.#{}, nif_funcs, &load, &reload, &upgrade, &unload)
    """
  end
end