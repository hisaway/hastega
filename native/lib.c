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
const int fail = 0;
const int success = 1;
const int empty = 0;
const size_t cache_line_size = 64;
const size_t size_t_max = -1;
const size_t init_size_long = cache_line_size / sizeof(long);
const size_t init_size_double = cache_line_size / sizeof(double);
const size_t size_t_highest_bit = ~(size_t_max >> 1);

#define loop_vectorize_width 4

int enif_get_long_vec_from_list(ErlNifEnv *env, ERL_NIF_TERM list, long **vec, size_t *vec_l);
int enif_get_double_vec_from_list(ErlNifEnv *env, ERL_NIF_TERM list, double **vec, size_t *vec_l);
int enif_get_double_vec_from_number_list(ErlNifEnv *env, ERL_NIF_TERM list, double **vec, size_t *vec_l);

ERL_NIF_TERM enif_make_list_from_long_vec(ErlNifEnv *env, const long *vec, const size_t vec_l);
ERL_NIF_TERM enif_make_list_from_double_vec(ErlNifEnv *env, const double *vec, const size_t vec_l);

ERL_NIF_TERM
enif_make_list_from_long_vec(ErlNifEnv *env, const long *vec, const size_t vec_l)
{
  ERL_NIF_TERM list = enif_make_list(env, 0);
  for(size_t i = vec_l; i > 0; i--) {
    ERL_NIF_TERM tail = list;
    ERL_NIF_TERM head = enif_make_int64(env, vec[i - 1]);
    list = enif_make_list_cell(env, head, tail);
  }
  return list;
}

ERL_NIF_TERM
enif_make_list_from_double_vec(ErlNifEnv *env, const double *vec, const size_t vec_l)
{
  ERL_NIF_TERM list = enif_make_list(env, 0);
  for(size_t i = vec_l; i > 0; i--) {
    ERL_NIF_TERM tail = list;
    ERL_NIF_TERM head = enif_make_double(env, vec[i - 1]);
    list = enif_make_list_cell(env, head, tail);
  }
  return list;
}

int
enif_get_long_vec_from_list(ErlNifEnv *env, ERL_NIF_TERM list, long **vec, size_t *vec_l)
{
  ERL_NIF_TERM head, tail;

  if (__builtin_expect((enif_get_list_cell(env, list, &head, &tail) == fail),
                       true)) {
    if (__builtin_expect((enif_is_empty_list(env, list) == success), true)) {
      *vec_l = empty;
      *vec = NULL;
      return success;
    }
    return fail;
  }
  size_t n = init_size_long;
  size_t nn = cache_line_size;
  long *t = (long *)enif_alloc(nn);
  if (__builtin_expect((t == NULL), false)) {
    return fail;
  }

  size_t i = 0;
  ERL_NIF_TERM tmp[loop_vectorize_width];
  int tmp_r[loop_vectorize_width];
  while (true) {
#pragma clang loop vectorize(disable)
    for (size_t count = 0; count < loop_vectorize_width; count++) {
      tmp[count] = head;
      if (__builtin_expect(
              (enif_get_list_cell(env, tail, &head, &tail) == fail), false)) {
        for (size_t c = 0; c <= count; c++) {
          tmp_r[c] = enif_get_int64(env, tmp[c], &t[i++]);
        }
        int acc = true;
#pragma clang loop vectorize(enable)
        for (size_t c = 0; c <= count; c++) {
          acc &= (tmp_r[c] == success);
        }
        if (__builtin_expect((acc == false), false)) {
          enif_free(t);
          return fail;
        }

        *vec_l = i;
        *vec = t;
        return success;
      }
    }
    if (__builtin_expect((i > size_t_max - loop_vectorize_width), false)) {
      enif_free(t);
      return fail;
    }
    if (__builtin_expect((i + loop_vectorize_width > n), false)) {
      size_t old_nn = nn;
      if (__builtin_expect(((nn & size_t_highest_bit) == 0), true)) {
        nn <<= 1;
        n <<= 1;
      } else {
        nn = size_t_max;
        n = nn / sizeof(long);
      }
      long *new_t = (long *)enif_alloc(nn);
      if(__builtin_expect((new_t == NULL), false)) {
        enif_free(t);
        return fail;
      }
      memcpy(new_t, t, old_nn);
      enif_free(t);
      t = new_t;
    }
#pragma clang loop vectorize(enable) unroll(enable)
    for (size_t count = 0; count < loop_vectorize_width; count++) {
      tmp_r[count] = enif_get_int64(env, tmp[count], &t[i + count]);
    }
    int acc = true;
#pragma clang loop vectorize(enable) unroll(enable)
    for (size_t count = 0; count < loop_vectorize_width; count++) {
      acc &= (tmp_r[count] == success);
    }
    if (__builtin_expect((acc == false), false)) {
      enif_free(t);
      return fail;
    }
    i += loop_vectorize_width;
  }
}

int
enif_get_double_vec_from_list(ErlNifEnv *env, ERL_NIF_TERM list, double **vec, size_t *vec_l)
{
  ERL_NIF_TERM head, tail;

  if (__builtin_expect((enif_get_list_cell(env, list, &head, &tail) == fail),
                       true)) {
    if (__builtin_expect((enif_is_empty_list(env, list) == success), true)) {
      *vec_l = empty;
      *vec = NULL;
      return success;
    }
    return fail;
  }
  size_t n = init_size_long;
  size_t nn = cache_line_size;
  double *t = (double *)enif_alloc(nn);
  if (__builtin_expect((t == NULL), false)) {
    return fail;
  }

  size_t i = 0;
  ERL_NIF_TERM tmp[loop_vectorize_width];
  int tmp_r[loop_vectorize_width];
  while (true) {
#pragma clang loop vectorize(disable)
    for (size_t count = 0; count < loop_vectorize_width; count++) {
      tmp[count] = head;
      if (__builtin_expect(
              (enif_get_list_cell(env, tail, &head, &tail) == fail), false)) {
        for (size_t c = 0; c <= count; c++) {
          tmp_r[c] = enif_get_double(env, tmp[c], &t[i++]);
        }
        int acc = true;
#pragma clang loop vectorize(enable)
        for (size_t c = 0; c <= count; c++) {
          acc &= (tmp_r[c] == success);
        }
        if (__builtin_expect((acc == false), false)) {
          enif_free(t);
          return fail;
        }

        *vec_l = i;
        *vec = t;
        return success;
      }
    }
    if (__builtin_expect((i > size_t_max - loop_vectorize_width), false)) {
      enif_free(t);
      return fail;
    }
    if (__builtin_expect((i + loop_vectorize_width > n), false)) {
      size_t old_nn = nn;
      if (__builtin_expect(((nn & size_t_highest_bit) == 0), true)) {
        nn <<= 1;
        n <<= 1;
      } else {
        nn = size_t_max;
        n = nn / sizeof(long);
      }
      double *new_t = (double *)enif_alloc(nn);
      if(__builtin_expect((new_t == NULL), false)) {
        enif_free(t);
        return fail;
      }
      memcpy(new_t, t, old_nn);
      enif_free(t);
      t = new_t;
    }
#pragma clang loop vectorize(enable) unroll(enable)
    for (size_t count = 0; count < loop_vectorize_width; count++) {
      tmp_r[count] = enif_get_double(env, tmp[count], &t[i + count]);
    }
    int acc = true;
#pragma clang loop vectorize(enable) unroll(enable)
    for (size_t count = 0; count < loop_vectorize_width; count++) {
      acc &= (tmp_r[count] == success);
    }
    if (__builtin_expect((acc == false), false)) {
      enif_free(t);
      return fail;
    }
    i += loop_vectorize_width;
  }
}

int
enif_get_double_vec_from_number_list(ErlNifEnv *env, ERL_NIF_TERM list, double **vec, size_t *vec_l)
{
  ERL_NIF_TERM head, tail;

  if (__builtin_expect((enif_get_list_cell(env, list, &head, &tail) == fail),
                       true)) {
    if (__builtin_expect((enif_is_empty_list(env, list) == success), true)) {
      *vec_l = empty;
      *vec = NULL;
      return success;
    }
    return fail;
  }
  size_t n = init_size_long;
  size_t nn = cache_line_size;
  double *t = (double *)enif_alloc(nn);
  if (__builtin_expect((t == NULL), false)) {
    return fail;
  }

  size_t i = 0;
  while (true) {
    if (__builtin_expect((enif_get_double(env, head, &t[i]) == fail), false)) {
      long tmp;
      if (__builtin_expect((enif_get_int64(env, head, &tmp) == fail), false)) {
        enif_free(t);
        return fail;
      }
      t[i] = (double)tmp;
    }
    i++;
    if (__builtin_expect(
          (enif_get_list_cell(env, tail, &head, &tail) == fail), false)) {
      *vec_l = i;
      *vec = t;
      return success;
    }
    if (__builtin_expect((i >= n), false)) {
      size_t old_nn = nn;
      if (__builtin_expect(((nn & size_t_highest_bit) == 0), true)) {
        nn <<= 1;
        n <<= 1;
      } else {
        nn = size_t_max;
        n = nn / sizeof(long);
      }
      double *new_t = (double *)enif_alloc(nn);
      if (__builtin_expect((new_t == NULL), false)) {
        enif_free(t);
        return fail;
      }
      memcpy(new_t, t, old_nn);
      enif_free(t);
      t = new_t;
    }
  }
}static ERL_NIF_TERM
map_mult(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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
      vec_double[i] = vec_double[i] * 2;
    }
    return enif_make_list_from_double_vec(env, vec_double, vec_l);
  }
#pragma clang loop vectorize_width(loop_vectorize_width)
  for(size_t i = 0; i < vec_l; i++) {
    vec_long[i] *= 2;
  }
  return enif_make_list_from_long_vec(env, vec_long, vec_l);
}
static
ErlNifFunc nif_funcs[] =
{
  // {erl_function_name, erl_function_arity, c_function}
  {"map_mult", 2, map_mult},
};
ERL_NIF_INIT(Elixir.HastegaNif, nif_funcs, &load, &reload, &upgrade, &unload)
