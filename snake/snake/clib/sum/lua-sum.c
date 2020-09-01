#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>

#include <lua.h>
#include <lauxlib.h>
#include <gdsl/gdsl_types.h>
#include <gdsl/gdsl_list.h>

#include "skynet_malloc.h"
#include "sum.h"

#define check_sum(L, idx)\
    *(struct sum_space**)luaL_checkudata(L, idx, "sum_meta")

static void sum_debug_print(const char* s) {
    FILE *f = fopen("sum_debug.log", "a");
    if (f == NULL)
        return;
    fprintf(f, "debug: %s\n", s);
    fflush(f);
    fclose(f);
}

static void *
my_alloc(void * ud, void *ptr, size_t sz) {
    if (ptr == NULL) {
        void *p = skynet_malloc(sz);
        return p;
    }
    skynet_free(ptr);
    return NULL;
}

static int sum_gc(lua_State* L) {
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        return 0;
    }
    sum_release(sum);
    sum = NULL;
    return 0;
}

static int lsum_create(lua_State* L){
    struct sum_space* sum = sum_create(my_alloc, NULL);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: fail to create sum");
        return 2;
    }

    *(struct sum_space**)lua_newuserdata(L, sizeof(void*)) = sum;
    luaL_getmetatable(L, "sum_meta");
    lua_setmetatable(L, -2);
    return 1;
}

static int lsum_set(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    int module = (int)luaL_checknumber(L, 2);
    const char* attr = luaL_checkstring(L, 3);
    double v = (double)luaL_checknumber(L, 4);

    sum_update(sum, module, attr, v, false);
    return 0;
}

static int lsum_add(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    int module = (int)luaL_checknumber(L, 2);
    const char* attr = luaL_checkstring(L, 3);
    double v = (double)luaL_checknumber(L, 4);

    sum_update(sum, module, attr, v, true);
    return 0;
}

static int lsum_clear(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    int module = (int)luaL_checknumber(L, 2);
    sum_clear(sum, module);
    return 0;
}

static void lsum_resetdaobiao(lua_State* L,const char * dname){
    lua_pushstring(L, dname);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);
}

static void lsum_setdaobiaos(lua_State* L,const char * dname,uint32_t idx,const char * attr){
    lua_pushstring(L, dname);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, attr);
    lua_rawseti(L,-2,idx);
    lua_pop(L,1);
}

static void lsum_setdaobiaof(lua_State* L,const char * dname,const char * attr,double value){
    lua_pushstring(L, dname);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, attr);
    lua_pushnumber(L, value);
    lua_rawset(L,-3);
    lua_pop(L,1);
}

inline static double lsum_getdaobiao(lua_State* L,const char * dname,const char * attr){
    lua_pushstring(L, dname);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, attr);
    lua_rawget(L, -2);
    double v = lua_tonumber(L,-1);
    lua_pop(L,2);
    return v;
}

static int lsum_receivedaobiao(lua_State* L,const char * dname,const char * stype){
    lsum_resetdaobiao(L,dname);
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        uint32_t type2 = lua_type(L, -2);
        uint32_t type1 = lua_type(L, -1);
        if ( strcmp(stype,"LIST") == 0 && type2 == LUA_TNUMBER && type1 == LUA_TSTRING ){
            uint32_t idx = lua_tonumber(L,-2);
            const char * key = lua_tostring(L,-1);
            lsum_setdaobiaos(L,dname,idx,key);
        }
        else if ( strcmp(stype,"TABLE") == 0 && type2 == LUA_TSTRING && type1 == LUA_TNUMBER ){
            const char * key = lua_tostring(L,-2);
            double v = lua_tonumber(L,-1);
            lsum_setdaobiaof(L,dname,key,v);
        }
        else
            sum_debug_print("receice daobiao data err");
        lua_pop(L,1);
    }
    lua_pop(L,1);
    return 0;
}

static int lsum_roleprop(lua_State* L){
    lsum_resetdaobiao(L,"ROLEPROP");
    lsum_receivedaobiao(L,"ROLEPROP","TABLE");
    return 0;
}

static int lsum_pointmacro(lua_State* L){
    lsum_resetdaobiao(L,"POINTMACRO");
    lsum_receivedaobiao(L,"POINTMACRO","LIST");
    return 0;
}

static int lsum_pointvalue(lua_State* L){
    lsum_resetdaobiao(L,"POINTVALUE");
    lsum_receivedaobiao(L,"POINTVALUE","TABLE");
    return 0;
}

static double lsum_getpointattr(lua_State* L,struct sum_space * space,const char * attr){
    double result = sum_result_find(space,MO_ATTR_POINT,attr);
    if ( result != -1 ) {
        return result;
    }
    result = lsum_getdaobiao(L,"ROLEPROP",attr);
    if ( strcmp(attr,"max_mp") == 0 ){
        result = result + (sum_find(space,MO_BASE,"grade") * 10 + 30);
    }
    else
    {   
        lua_pushstring(L, "POINTMACRO");
        lua_rawget(L, LUA_REGISTRYINDEX);
        lua_pushnil(L);
        char sother[30];
        while (lua_next(L, -2) != 0) {
            const char * macro = lua_tostring(L,-1);
            double tmp = sum_find(space,MO_BASE,macro);
            tmp = tmp + tmp * (sum_getbaseratio(space,macro) ) /100 + sum_getattradd(space,macro);
            sprintf(sother,"%s_%s_add",macro,attr);
            tmp = tmp * lsum_getdaobiao(L,"POINTVALUE",sother);
            result = result + tmp;
            lua_pop(L,1);
        }
        lua_pop(L,1);
        // if ( strcmp(attr,"max_hp") == 0 )
        //     result = result + (sum_find(space,MO_BASE,"grade")* 5);
    }
    sum_result_set(space,MO_ATTR_POINT,attr,result);
    return result;
}

static int lsum_getattr(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    const char * attr = luaL_checkstring(L, 2);
    double result = 0;
    if (strcmp(attr,"speed") == 0 || strcmp(attr,"mag_defense") == 0 ||\
        strcmp(attr,"phy_defense") == 0 || strcmp(attr,"mag_attack") == 0 ||\
        strcmp(attr,"phy_attack") == 0 || strcmp(attr,"max_hp") == 0 ||\
        strcmp(attr,"max_mp") == 0)
    {
        result = lsum_getpointattr(L,sum,attr);
    }
    else
    {
        result = sum_find(sum,MO_BASE,attr);
    }
    result = result + result * (sum_getbaseratio(sum,attr)) / 100 + sum_getattradd(sum,attr);
    lua_pushnumber(L, result);
    return 1;
}

static int lsum_getbaseattr(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    const char * attr = luaL_checkstring(L, 2);
    double result = 0;
    if (strcmp(attr,"speed") == 0 || strcmp(attr,"mag_defense") == 0 ||\
        strcmp(attr,"phy_defense") == 0 || strcmp(attr,"mag_attack") == 0 ||\
        strcmp(attr,"phy_attack") == 0 || strcmp(attr,"max_hp") == 0 ||\
        strcmp(attr,"max_mp") == 0)
    {
        result = lsum_getpointattr(L,sum,attr);
    }
    else
    {
        result = sum_find(sum,MO_BASE,attr);
    }
    lua_pushnumber(L, result);
    return 1;
}

static int lsum_getbaseratio(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    const char * attr = luaL_checkstring(L, 2);
    double result = sum_getbaseratio(sum,attr);
    lua_pushnumber(L, result);
    return 1;
}

static int lsum_getattradd(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    const char * attr = luaL_checkstring(L, 2);
    double result = sum_getattradd(sum,attr);
    lua_pushnumber(L, result);
    return 1;
}

static int lsum_print(lua_State* L){
    struct sum_space* sum = check_sum(L, 1);
    if (sum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: sum not args");
        return 2;
    }
    int module = (int)luaL_checknumber(L, 2);
    sum_print(sum,module);
    return 0;
}

static const struct luaL_Reg lsum_methods [] = {
    { "set" , lsum_set },
    { "add" , lsum_add },
    { "clear" , lsum_clear },
    { "getattr" , lsum_getattr},
    { "getbaseattr" , lsum_getbaseattr},
    { "getbaseratio" , lsum_getbaseratio},
    { "getattradd" , lsum_getattradd},
    { "print" , lsum_print},
    {NULL, NULL},
};

static const struct luaL_Reg l_methods[] = {
    { "lsum_create" , lsum_create },
    { "lsum_roleprop" , lsum_roleprop },
    { "lsum_pointmacro" , lsum_pointmacro },
    { "lsum_pointvalue" , lsum_pointvalue },
    {NULL, NULL},
};

int luaopen_lsum(lua_State* L) {
    luaL_checkversion(L);

    luaL_newmetatable(L, "sum_meta");

    lua_newtable(L);
    luaL_setfuncs(L, lsum_methods, 0);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, sum_gc);
    lua_setfield(L, -2, "__gc");

    luaL_newlib(L, l_methods);

    return 1;
}
