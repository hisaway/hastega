defmodule Hastega.Generator.Native do
  import Hastega.Db
  alias Hastega.Db
  alias SumMag.Opt

  @nif_c "native/lib.c"
  @nif_module "HastegaNif"
  @dir "lib/hastega/generator/native/"

  def generate do
    File.mkdir("native")
    @nif_c
    |> write
  end

  defp write(file) do
    str = init_nif |> basic |> generate_functions |> erl_nif_init

    file |> File.write(str)
  end

  defp generate_functions(str) do
    definition_func = 
    Db.get_functions
    |> Enum.map(& &1 |> generate_function)
    |> to_str_code

    str <> definition_func <> func_list
  end

  defp generate_function([func_info]) do
    enum_map(func_info)
  end

  defp to_str_code(list) when list |> is_list do
    list
    |> Enum.reduce(
      "", 
      fn x, acc -> acc <> to_string(x) end)
  end

  defp declare(str, func_name) do
    str <> """
    static void ERL_NIF_TERM #{func_name}(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
    """
  end

  defp func_list do
    fl = Db.get_functions
    |> Enum.reduce(
      "", 
      fn x, acc -> 
        str = x |> erl_nif_func
        acc <> "#{str},"end)

    """
    static
    ErlNifFunc nif_funcs[] =
    {
      // {erl_function_name, erl_function_arity, c_function}
      #{fl}
    };
    """
  end

  defp erl_nif_func([info]) do
     %{
      nif_name: nif_name,
      module: module,
      function: func_name,
      arg_num: num,
      args: args,
      operators: operators
    } = info

    ~s/{"#{nif_name}", #{num}, #{nif_name}}/
  end

  defp init_nif do
    """
    #include<stdbool.h>
    #include<erl_nif.h>
    #include<string.h>

    static int load(ErlNifEnv *env, void **priv, ERL_NIF_TERM info);
    static void unload(ErlNifEnv *env, void *priv);
    static int reload(ErlNifEnv *env, void **priv, ERL_NIF_TERM info);
    static int upgrade(ErlNifEnv *env, void **priv, void **old_priv, ERL_NIF_TERM info);

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
    """
  end

  defp erl_nif_init(str) do
    str <> """
    ERL_NIF_INIT(Elixir.#{@nif_module}, nif_funcs, &load, &reload, &upgrade, &unload)
    """
  end

  defp basic(str) do
    {:ok, ret} = File.read(@dir <> "basic.c")

    str <> ret
  end

  defp arithmetic(str) do
    str <> File.read(@dir <> "arithmetic.c")
  end

  # defp enum_map_(str, operator, num)
  defp enum_map(info) do
    %{
      nif_name: nif_name,
      module: module,
      function: func_name,
      arg_num: num,
      args: args,
      operators: operators
    } = info

    operator = hd operators
    [_captured, arg] = args

    """
    static ERL_NIF_TERM
    #{nif_name}(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
    {
      if (__builtin_expect((argc != 1), false)) {
        return enif_make_badarg(env);
      }
      long *vec_long;
      size_t vec_l;
      double *vec_double;
      if (__builtin_expect((enif_get_long_vec_from_list(env, argv[0], &vec_long, &vec_l) == fail), false)) {
        if (__builtin_expect((enif_get_double_vec_from_list(env, argv[0], &vec_double, &vec_l) == fail), false)) {
          return enif_make_badarg(env);
        }
    #pragma clang loop vectorize_width(loop_vectorize_width)
        for(size_t i = 0; i < vec_l; i++) {
          vec_double[i] = vec_double[i] #{operator} #{arg};
        }
        return enif_make_list_from_double_vec(env, vec_double, vec_l);
      }
    #pragma clang loop vectorize_width(loop_vectorize_width)
      for(size_t i = 0; i < vec_l; i++) {
        vec_long[i] *= 2;
      }
      return enif_make_list_from_long_vec(env, vec_long, vec_l);
    }
    """
  end

  defp chunk_every(str) do
    str <> File.read(@dir <> "enum.c")
  end
end