#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <math.h>

#include <lua.h>
#include <lauxlib.h>
#include <gdsl/gdsl_types.h>
#include <gdsl/gdsl_list.h>

#include "skynet_malloc.h"
#include "psum.h"

#define check_psum(L, idx)\
    *(struct psum_space**)luaL_checkudata(L, idx, "psum_meta")

static void psum_debug_print(const char* s) {
    FILE *f = fopen("psum_debug.log", "a");
    if (f == NULL)
        return;
    fprintf(f, "debug: %s\n", s);
    fflush(f);
    fclose(f);
}

static int psum_gc(lua_State* L) {
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        return 0;
    }
    psum_release(psum);
    psum = NULL;
    return 0;
}

static int lpsum_create(lua_State* L){
    struct psum_space* psum = psum_create();
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: fail to create psum");
        return 2;
    }

    *(struct psum_space**)lua_newuserdata(L, sizeof(void*)) = psum;
    luaL_getmetatable(L, "psum_meta");
    lua_setmetatable(L, -2);
    return 1;
}

static void lpsum_resetdaobiao(lua_State* L,const char * dname){
    lua_pushstring(L, dname);
    lua_newtable(L);
    lua_rawset(L, LUA_REGISTRYINDEX);
}

static void lpsum_setdaobiaos(lua_State* L,const char * dname,uint32_t idx,const char * attr){
    lua_pushstring(L, dname);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, attr);
    lua_rawseti(L,-2,idx);
    lua_pop(L,1);
}

static void lpsum_setdaobiaof(lua_State* L,const char * dname,const char * attr,double value){
    lua_pushstring(L, dname);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, attr);
    lua_pushnumber(L, value);
    lua_rawset(L,-3);
    lua_pop(L,1);
}

inline static double lpsum_getdaobiao(lua_State* L,const char * dname,const char * attr){
    lua_pushstring(L, dname);
    lua_rawget(L, LUA_REGISTRYINDEX);
    lua_pushstring(L, attr);
    lua_rawget(L, -2);
    double v = lua_tonumber(L,-1);
    lua_pop(L,2);
    return v;
}

static int lpsum_receivedaobiao(lua_State* L,const char * dname,const char * stype){
    lpsum_resetdaobiao(L,dname);
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        uint32_t type2 = lua_type(L, -2);
        uint32_t type1 = lua_type(L, -1);
        if ( strcmp(stype,"LIST") == 0 && type2 == LUA_TNUMBER && type1 == LUA_TSTRING ){
            uint32_t idx = lua_tonumber(L,-2);
            const char * key = lua_tostring(L,-1);
            lpsum_setdaobiaos(L,dname,idx,key);
        }
        else if ( strcmp(stype,"TABLE") == 0 && type2 == LUA_TSTRING && type1 == LUA_TNUMBER ){
            const char * key = lua_tostring(L,-2);
            double v = lua_tonumber(L,-1);
            lpsum_setdaobiaof(L,dname,key,v);
        }
        else
            psum_debug_print("receice daobiao data err");
        lua_pop(L,1);
    }
    lua_pop(L,1);
    return 0;
}

static int lpsum_roleprop(lua_State* L){
    lpsum_resetdaobiao(L,"ROLEPROP");
    lpsum_receivedaobiao(L,"ROLEPROP","TABLE");
    return 0;
}

static int lpsum_pointmacro(lua_State* L){
    lpsum_resetdaobiao(L,"POINTMACRO");
    lpsum_receivedaobiao(L,"POINTMACRO","LIST");
    return 0;
}

static int lpsum_pointvalue(lua_State* L){
    lpsum_resetdaobiao(L,"POINTVALUE");
    lpsum_receivedaobiao(L,"POINTVALUE","TABLE");
    return 0;
}

static int lpsum_set(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    const char* attr = luaL_checkstring(L, 2);
    uint8_t module = (uint8_t)luaL_checknumber(L, 3);
    double v = (double)luaL_checknumber(L, 4);

    psum_update(psum, attr, module, v, false);
    return 0;
}

static int lpsum_add(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    const char* attr = luaL_checkstring(L, 2);
    uint8_t module = (uint8_t)luaL_checknumber(L, 3);
    double v = (double)luaL_checknumber(L, 4);

    psum_update(psum, attr, module, v, true);
    return 0;
}

static int lpsum_setgrade(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    int v = (int)luaL_checknumber(L, 2);
    psum_setgrade(psum, v);
    return 0;
}

static int lpsum_getbaseratio(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    const char * attrkey = luaL_checkstring(L, 2);
    const uint8_t attr = (uint8_t)psum_getattrindex(attrkey);
    if (attr == -1) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum index -1");
        return 2; 
    }

    double result = psum_getbaseratio(psum,attr);
    lua_pushnumber(L, result);
    return 1;
}

static int lpsum_getattradd(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    const char * attrkey = luaL_checkstring(L, 2);
    const uint8_t attr = psum_getattrindex(attrkey);
    if (attr == -1) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum index -1");
        return 2; 
    }

    double result = psum_getattradd(psum,attr);
    lua_pushnumber(L, result);
    return 1;
}

static double lpsum_calbaseattr(lua_State* L,struct psum_space * space,const char * attrkey, const uint8_t attr){
    double result = lpsum_getdaobiao(L,"ROLEPROP",attrkey);
    if ( strcmp(attrkey, "max_mp") == 0 ){
        result = result + (psum_getgrade(space) * 10 + 30);
    }
    else {   
        lua_pushstring(L, "POINTMACRO");
        lua_rawget(L, LUA_REGISTRYINDEX);
        lua_pushnil(L);
        char sother[30];
        while (lua_next(L, -2) != 0) {
            const char * macro = lua_tostring(L,-1);
            const uint8_t index = psum_getattrindex(macro);
            if (index == -1)
                break;

            double tmp = psum_find(space,index,MO_BASE);
            tmp = tmp + tmp * (psum_getbaseratio(space,index)) /100 + psum_getattradd(space,index);
            sprintf(sother,"%s_%s_add",macro,attrkey);
            tmp = tmp * lpsum_getdaobiao(L,"POINTVALUE",sother);
            result = result + tmp;
            lua_pop(L,1);
        }
        lua_pop(L,1);
        // if ( strcmp(attrkey,"max_hp") == 0 )
        //     result = result + (psum_getgrade(space)* 5);
    }
    return result;
}

static double lpsum_getbaseresult(lua_State* L,struct psum_space * space,const char * attrkey, const uint8_t attr){
    double result = floor(psum_find(space,attr,MO_ATTR_POINT));
    if ( result != -1 ) {
        return result;
    }

    if (strcmp(attrkey,"speed") == 0 || strcmp(attrkey,"mag_defense") == 0 ||\
        strcmp(attrkey,"phy_defense") == 0 || strcmp(attrkey,"mag_attack") == 0 ||\
        strcmp(attrkey,"phy_attack") == 0 || strcmp(attrkey,"max_hp") == 0 ||\
        strcmp(attrkey,"max_mp") == 0)
    {
        result = lpsum_calbaseattr(L,space,attrkey,attr);
    }
    else
    {
        result = psum_getbaseattr(space,attr);
    }
    psum_update(space,attrkey,MO_ATTR_POINT,result,false);
    return result;
}

static int lpsum_getattr(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    const char * attrkey = luaL_checkstring(L, 2);
    const uint8_t attr = psum_getattrindex(attrkey);
    if (attr == -1) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum index -1");
        return 2; 
    }

    double result = lpsum_getbaseresult(L, psum, attrkey, attr);
    result = result + result * (psum_getbaseratio(psum, attr)) / 100 + psum_getattradd(psum,attr);
    lua_pushnumber(L, result);
    return 1;
}

static int lpsum_getbaseattr(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    const char * attrkey = luaL_checkstring(L, 2);
    const uint8_t attr = psum_getattrindex(attrkey);
    if (attr == -1) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum index -1");
        return 2; 
    }

    double result = lpsum_getbaseresult(L, psum, attrkey, attr);
    lua_pushnumber(L, result);
    return 1;
}

static int lpsum_clear(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    uint8_t module = (uint8_t)luaL_checknumber(L, 2);
    psum_clear(psum, module);
    return 0;
}

static int lpsum_print(lua_State* L){
    struct psum_space* psum = check_psum(L, 1);
    if (psum == NULL) {
        lua_pushnil(L);
        lua_pushstring(L, "error: psum not args");
        return 2;
    }
    uint8_t module = (uint8_t)luaL_checknumber(L, 2);
    psum_print(psum, module);
    return 0;
}

static const struct luaL_Reg lpsum_methods [] = {
    { "set" , lpsum_set},
    { "add" , lpsum_add},
    { "clear" , lpsum_clear},
    { "setgrade" , lpsum_setgrade},
    { "getattr" , lpsum_getattr},
    { "getbaseattr" , lpsum_getbaseattr},
    { "getbaseratio" , lpsum_getbaseratio},
    { "getattradd" , lpsum_getattradd},
    { "print" , lpsum_print },
    {NULL, NULL},
};

static const struct luaL_Reg l_methods[] = {
    { "lpsum_create" , lpsum_create },
    { "lpsum_roleprop" , lpsum_roleprop },
    { "lpsum_pointmacro" , lpsum_pointmacro },
    { "lpsum_pointvalue" , lpsum_pointvalue },
    {NULL, NULL},
};

int luaopen_lpsum(lua_State* L) {
    luaL_checkversion(L);

    luaL_newmetatable(L, "psum_meta");

    lua_newtable(L);
    luaL_setfuncs(L, lpsum_methods, 0);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, psum_gc);
    lua_setfield(L, -2, "__gc");

    luaL_newlib(L, l_methods);

    return 1;
}
