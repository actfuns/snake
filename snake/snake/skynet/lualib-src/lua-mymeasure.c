#include "skynet.h"
#include "skynet_malloc.h"

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#if defined(__APPLE__)
#include <sys/time.h>
#endif

//upvalues
#define YIELD_RESUME 1

//key
#define TOTAL_TIME 1
#define TIMESTAMP 2
#define DEBUG_TIME 3

//tree
#define TREE_ROOT 1
#define STACK_BOTTLE 2
#define STACK_HIGHT 3

//stacklimit
#define STATCK_LIMIT 15
#define NAME_LENGTH 200
#define TREE_WIDTH 100

struct TreeNode {
    char key[NAME_LENGTH];
    uint64_t timestamp;
    uint64_t time;        //函数耗时，减去hook耗时
    int cnt;        //函数内总共调用了多少次hook
    struct TreeNode *child;
    struct TreeNode *sibling;
};

static inline struct skynet_context*
get_ctx(lua_State *L)
{
    lua_getfield(L, LUA_REGISTRYINDEX, "skynet_context");
    struct skynet_context *ctx = lua_touserdata(L,-1);
    lua_pop(L, 1);
    return ctx;
}

static void *
my_alloc(void *ptr, size_t sz) {
    if (ptr == NULL) {
        void *p = skynet_malloc(sz);
        return p;
    }
    skynet_free(ptr);
    return NULL;
}

static inline void
newmetatable(lua_State *L)
{
    lua_newtable(L);
    lua_pushliteral(L, "k");
    lua_setfield(L, -2, "__mode");
    return ;
}

static uint64_t
timestamp()
{
    uint64_t ms = 0;
#if !defined(__APPLE__)
    struct timespec ti;
    clock_gettime(CLOCK_REALTIME, &ti);
    ms += (uint64_t)(ti.tv_sec*1000*10);
    ms += (uint64_t)(ti.tv_nsec/100000);
#else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    ms += (uint64_t)(tv.tv_sec*1000*10);
    ms += (uint64_t)(tv.tv_usec/100);
#endif
    return ms;
}

static inline uint64_t
diff(uint64_t last, uint64_t now)
{
    return (now > last) ? (now - last) : 0;
}

static void
cotimestamp(lua_State *L, uint64_t stamp)
{
    lua_pushstring(L, "MYMEASURE_CO_MAP");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushthread(L);
    lua_rawget(L, -2);

    int i1;
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
    } else {
        i1 = lua_gettop(L);

        lua_pushinteger(L, stamp);
        lua_rawseti(L, i1, TIMESTAMP);

        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

static uint64_t
coupdate(lua_State *L, uint64_t stamp)
{
    lua_pushstring(L, "MYMEASURE_CO_MAP");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushthread(L);
    lua_rawget(L, -2);

    uint64_t ret_time = 0;
    int i1;
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);

        lua_pushthread(L);
        lua_newtable(L);
        i1 = lua_gettop(L);

        lua_pushinteger(L, 0);
        lua_rawseti(L, i1, TOTAL_TIME);
        lua_pushinteger(L, stamp);
        lua_rawseti(L, i1, TIMESTAMP);
        lua_pushinteger(L, -1);
        lua_rawseti(L, i1, DEBUG_TIME);

        lua_rawset(L, -3);
        ret_time = 0;
    } else {
        i1 = lua_gettop(L);

        lua_rawgeti(L, i1, TOTAL_TIME);
        lua_rawgeti(L, i1, TIMESTAMP);
        uint64_t total_time = lua_tointeger(L, -2);
        uint64_t timestamp = lua_tointeger(L, -1);
        lua_pop(L, 2);

        ret_time = total_time + (stamp - timestamp);
        lua_pushinteger(L, ret_time);
        lua_rawseti(L, i1, TOTAL_TIME);
        lua_pushinteger(L, stamp);
        lua_rawseti(L, i1, TIMESTAMP);

        lua_pop(L, 1);
    }

    lua_pop(L, 1);

    return ret_time;
}

static void
on_enter_func(lua_State *L, char *callname) {
    uint64_t sts = timestamp();
    uint64_t ts = coupdate(L, sts);

    lua_pushstring(L, "MYMEASURE_NOTE_MAP");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushthread(L);
    lua_rawget(L, -2);

    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);

        lua_pushthread(L);
        lua_newtable(L);

        struct TreeNode *p = (struct TreeNode *)my_alloc(NULL, sizeof(*p));
        memcpy(p->key, callname, strlen(callname) + 1);
        p->timestamp = ts;
        p->time = 0;
        p->cnt = 1;
        p->child = NULL;
        p->sibling = NULL;

        struct TreeNode ** sb = (struct TreeNode **)my_alloc(NULL, sizeof(*sb)*STATCK_LIMIT);
        *sb = p;
        // printf("xiong sb init %p %p \n", sb, p);
        // fflush(stdout);

        lua_pushlightuserdata(L, p);
        lua_rawseti(L, -2, TREE_ROOT);
        lua_pushlightuserdata(L, sb);
        lua_rawseti(L, -2, STACK_BOTTLE);
        lua_pushinteger(L, 1);
        lua_rawseti(L, -2, STACK_HIGHT);

        lua_rawset(L, -3);
    } else {
        lua_rawgeti(L, -1, STACK_HIGHT);
        int sh = lua_tointeger(L, -1);
        lua_rawgeti(L, -2, STACK_BOTTLE);
        struct TreeNode ** sb = (struct TreeNode **)lua_touserdata(L, -1);
        lua_pop(L, 2);

        lua_pushinteger(L, sh + 1);
        lua_rawseti(L, -2, STACK_HIGHT);

        int t = sh;
        if (sh > STATCK_LIMIT) t = STATCK_LIMIT;
        // printf("xiong statck hight %p %d %d\n", sb, t, sh);
        // fflush(stdout);
        struct TreeNode *n = *(sb + t - 1);
        // printf("xiong sb get %p now %p n %p \n", sb, sb + t - 1, n);
        // fflush(stdout);

        if (sh < STATCK_LIMIT) {
            struct TreeNode *p = n->child;
            struct TreeNode *l = NULL;
            while (p) {
                if (strcmp(p->key, callname) == 0) break;
                l = p;
                p = p->sibling;
            }
            if (p) {
                p->cnt += 1;
                p->timestamp = ts;
            } else {
                p = (struct TreeNode *)my_alloc(NULL, sizeof(*p));
                memcpy(p->key, callname, strlen(callname) + 1);
                p->timestamp = ts;
                p->time = 0;
                p->cnt = 1;
                p->child = NULL;
                p->sibling = NULL;
                if (!n->child) {
                    n->child = p;
                } else {
                    l->sibling = p;
                }
            }

            *(sb + sh) = p;
            // printf("xiong sb add %p p %p \n", sb + sh, p);
            // fflush(stdout);
        } else {
            n->cnt += 1;
        }

        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

static void
on_leave_func(lua_State *L, char *callname) {
    uint64_t sts = timestamp();
    uint64_t ts = coupdate(L, sts);

    lua_pushstring(L, "MYMEASURE_NOTE_MAP");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushthread(L);
    lua_rawget(L, -2);

    if (!lua_isnil(L, -1)) {
        lua_rawgeti(L, -1, STACK_HIGHT);
        int sh = lua_tointeger(L, -1);
        lua_pop(L, 1);
        lua_pushinteger(L, sh - 1);
        lua_rawseti(L, -2, STACK_HIGHT);

        if (sh <= STATCK_LIMIT) {
            lua_rawgeti(L, -1, STACK_BOTTLE);
            struct TreeNode ** sb = (struct TreeNode **)lua_touserdata(L, -1);
            lua_pop(L, 1);

            struct TreeNode *n = *(sb + sh - 1);
            // printf("xiong on_leave_func %p p %p \n", sb + sh -1, n);
            // fflush(stdout);

            n->time += diff(n->timestamp, ts);
        }

        lua_pop(L, 1);
    } else {
        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

static void
hook(lua_State *L, lua_Debug *ar) {
      lua_getinfo(L, "nS", ar);

      char callname[NAME_LENGTH];
      sprintf(callname, "%s line:%d func:%s", ar->short_src, ar->linedefined, ar->name);

      if (strcmp(ar->what, "C")) {
        // printf("xiong hook %p %d %s \n", L, ar->event, callname);
        // fflush(stdout);
          if (ar->event == 0) {
              on_enter_func(L, callname);
          } else if (ar->event == 4) {
              lua_Debug previous_ar;
              if (lua_getstack(L, 1, &previous_ar) != 0) {
                  lua_getinfo(L, "nS", &previous_ar);
                  char precallname[NAME_LENGTH];
                  sprintf(precallname, "%s line:%d func:%s", previous_ar.short_src, previous_ar.linedefined, previous_ar.name);
                // printf("xiong hook222 %p %d %s \n", L, ar->event, precallname);
                // fflush(stdout);
                  on_leave_func(L, precallname);
              }
              on_enter_func(L, callname);
          } else {
              on_leave_func(L, callname);
          }
      }
}

static void
freetree(struct TreeNode *r)
{
    struct TreeNode *s[STATCK_LIMIT];
    int sh = 0;

    struct TreeNode *p = r;
    struct TreeNode *f;
    while (p || sh > 0) {
        if (p) {
            *(s + sh) = p;
            sh += 1;
            p = p->child;
        } else {
            p = *(s + sh -1);
            sh -= 1;
            f = p;
            p = p->sibling;
            my_alloc(f, 0);
        }
    }
}

static int 
_comp_cost(const void * a, const void * b) {
    const struct TreeNode * ca = *((const struct TreeNode **)a);
    const struct TreeNode * cb = *((const struct TreeNode **)b);

    uint64_t diff_time = cb->time - ca->time;
    if (diff_time != 0) {
        return diff_time;
    } else {
        return cb->cnt < ca->cnt;
    }
}

static void
printstatck(lua_State *L)
{
    struct skynet_context * ctx = get_ctx(L);
    lua_pushstring(L, "MYMEASURE_NOTE_MAP");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushthread(L);
    lua_rawget(L, -2);

    if (!lua_isnil(L, -1)) {
        lua_rawgeti(L, -1, TREE_ROOT);
        struct TreeNode *r = (struct TreeNode *)lua_touserdata(L, -1);
        lua_pop(L, 1);

        struct TreeNode *s[STATCK_LIMIT];
        int sh = 0;
        struct TreeNode *p = r;
        while (p || sh > 0) {
            if (p) {
                *(s + sh) = p;
                sh += 1;
                p = p->child;
            } else {
                p = *(s + sh -1);
                sh -= 1;
                // cal parent hook call cnt
                if (sh > 0) {
                    (*(s + sh -1))->cnt += p->cnt;
                }

                p = p->sibling;
            }
        }

        sh = 0;
        p = r;
        struct TreeNode *a[TREE_WIDTH];
        int l = 0;
        struct TreeNode *t;
        struct TreeNode *t2;
        int i;
        while (p || sh > 0) {
            if (p) {
                // sort and cut
                if (p->child) {
                    t = p->child;
                    l = 0;
                    while (t) {
                        t2 = t->sibling;
                        t->sibling = NULL;
                        if (t->time <= 10) {
                            freetree(t);
                        } else {
                            a[l] = t;
                            l += 1;
                        }
                        t = t2;
                    }
                    if (l > 0) {
                        qsort(a, l, sizeof(struct TreeNode *), _comp_cost);
                        t = a[0];
                        p->child = t;
                        for (i = 1; i < l; i++) {
                            t->sibling = a[i];
                            t = a[i];
                        }
                    } else {
                        p->child = NULL;
                    }
                }

                if (p->sibling) {
                    *(s + sh) = p->sibling;
                    sh += 1;
                }
                p = p->child;
            } else {
                p = *(s + sh - 1);
                sh -= 1;
            }
        }

        sh = 0;
        p = r;
        int hs[STATCK_LIMIT];
        int h = 0;
        char cs[NAME_LENGTH] = {'\0'};
        char callname[NAME_LENGTH] = {'\0'};
        while (p || sh > 0) {
            if (p) {
                // beauty print
                if (p->sibling) {
                    cs[2*h] = '|';
                    cs[2*h+1] = ' ';
                } else {
                    cs[2*h] = ' ';
                    cs[2*h+1] = ' ';
                }
                if (h > 0) {
                    memcpy(callname, cs, 2*h*sizeof(char));
                }
                callname[2*h] = '\\';
                callname[2*h+1] = '_';
                  sprintf(callname + 2 * h + 2, "%-5ld %-5d %s", (uint64_t)(p->time/10), p->cnt, p->key);
                skynet_error(ctx, "%s", callname);

                if (p->sibling) {
                    *(s + sh) = p->sibling;
                    *(hs + sh) = h;
                    sh += 1;
                }
                p = p->child;
                h += 1;
            } else {
                p = *(s + sh - 1);
                h = *(hs + sh -1);
                sh -= 1;
            }
        }

        lua_pop(L, 1);
    } else {
        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

static void
destroy(lua_State *L)
{
    lua_pushstring(L, "MYMEASURE_NOTE_MAP");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushthread(L);
    lua_rawget(L, -2);

    if (!lua_isnil(L, -1)) {
        lua_rawgeti(L, -1, TREE_ROOT);
        struct TreeNode *r = (struct TreeNode *)lua_touserdata(L, -1);
        lua_rawgeti(L, -2, STACK_BOTTLE);
        struct TreeNode **s = (struct TreeNode **)lua_touserdata(L, -1);
        lua_pop(L, 2);

        freetree(r);
        my_alloc(s, 0);

        lua_pop(L, 1);

        lua_pushthread(L);
        lua_pushnil(L);
        lua_rawset(L, -3);
    } else {
        lua_pop(L, 1);
    }

    lua_pop(L, 1);
}

static int
lopen(lua_State *L)
{
    luaL_checktype(L, -1, LUA_TTHREAD);
    lua_State *L1 = lua_tothread(L, -1);
    lua_sethook(L1, (lua_Hook)hook, LUA_MASKCALL | LUA_MASKRET, 0);

    // printf("xiong open state %p \n", L1);
    // fflush(stdout);
    char callname[NAME_LENGTH];
    sprintf(callname, "measure info");
    on_enter_func(L1, callname);
    if (L == L1) {
        sprintf(callname, "consume hook");
        on_enter_func(L1, callname);
    }
    return 0;
}

static int
lclose(lua_State *L)
{
    luaL_checktype(L, -1, LUA_TTHREAD);
    lua_State *L1 = lua_tothread(L, -1);
    lua_sethook(L1, (lua_Hook)hook, 0, 0);

    char callname[NAME_LENGTH];
    if (L == L1) {
        sprintf(callname, "consume hook");
        on_leave_func(L1, callname);
    }
    sprintf(callname, "measure info");
    on_leave_func(L1, callname);
    // printf("xiong close %p \n", L1);
    // fflush(stdout);
    printstatck(L1);
    destroy(L1);
    return 0;
}

static int
lyield(lua_State *L) {
    uint64_t sts = timestamp();
    coupdate(L, sts);
    lua_CFunction co_yield = lua_tocfunction(L, lua_upvalueindex(YIELD_RESUME));
    return co_yield(L);
}

static int
lresume(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTHREAD);

    uint64_t sts = timestamp();

    lua_State* mL = lua_tothread(L, 1);
    cotimestamp(mL, sts);

    lua_CFunction co_resume = lua_tocfunction(L, lua_upvalueindex(YIELD_RESUME));
    return co_resume(L);
}

int
luaopen_mymeasure(lua_State *L) {
    luaL_checkversion(L);

    luaL_Reg l[] = {
        { "open" , lopen },
        { "close" , lclose },
        { "yield" , lyield },
        { "resume" , lresume },
        { NULL, NULL },
    };

    //MYMEASURE_WEAKTABLE_META
    lua_pushstring(L, "MYMEASURE_WEAKTABLE_META");
    newmetatable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);
    //MYMEASURE_NOTE_MAP
    lua_pushstring(L, "MYMEASURE_NOTE_MAP");
    lua_newtable(L);
    lua_pushstring(L, "MYMEASURE_WEAKTABLE_META");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_setmetatable(L, -2);
    lua_rawset(L, LUA_REGISTRYINDEX);
    //MYMEASURE_CO_MAP
    lua_pushstring(L, "MYMEASURE_CO_MAP");
    lua_newtable(L);
    lua_pushstring(L, "MYMEASURE_WEAKTABLE_META");
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_setmetatable(L, -2);
    lua_rawset(L, LUA_REGISTRYINDEX);

    luaL_newlibtable(L, l);

    // cfunction (coroutine.resume or coroutine.yield)
    lua_pushnil(L);
    luaL_setfuncs(L, l, 1);

    int libtable = lua_gettop(L);

    lua_getglobal(L, "coroutine");

    lua_getfield(L, -1, "resume");
    lua_CFunction co_resume = lua_tocfunction(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, libtable, "resume");
    lua_pushcfunction(L, co_resume);
    lua_setupvalue(L, -2, 1);
    lua_pop(L, 1);

    lua_getfield(L, -1, "yield");
    lua_CFunction co_yield = lua_tocfunction(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, libtable, "yield");
    lua_pushcfunction(L, co_yield);
    lua_setupvalue(L, -2, 1);
    lua_pop(L, 1);

    lua_settop(L, libtable);

    return 1;
}
