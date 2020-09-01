#ifndef _SUM_H
#define _SUM_H

#include <stdint.h>
#include <stddef.h>

// lua层同步定义
#define MO_CNT 17

typedef enum
{
    MO_ATTR_ADD = 0,
    MO_ATTR_BASE_R = 1,
    MO_ATTR_POINT = 2,
    MO_BASE = 3,
    MO_PARTNER = 4,
    MO_RIDE = 5,
    MO_TOUXIAN = 6,
    MO_SKILL_MGR = 7,
    MO_SKILL_MGR_R = 8,
    MO_EQUIP_MGR = 9,
    MO_EQUIP_MGR_R = 10,
    MO_RIDE_MGR = 11,
    MO_RIDE_MGR_R = 12,
    MO_TITLE_MGR = 13,
    MO_TITLE_MGR_R = 14,
    MO_FABAO_MGR = 15,
    MO_FABAO_MGR_R = 16,
} sum_modules;

typedef void * (*sum_Alloc)(void *ud, void * ptr, size_t sz);

struct sum_space;

struct sum_space * sum_create(sum_Alloc alloc, void *ud);
void sum_release(struct sum_space *);

double sum_find(struct sum_space * space , int module, const char * attr);
double sum_result_find(struct sum_space * space , int module, const char * attr);
void sum_update(struct sum_space * space , int module, const char * attr, double value, bool add);
void sum_result_set(struct sum_space * space , int module, const char * attr, double value);

double sum_getattradd(struct sum_space * space , const char * attr);
double sum_getbaseratio(struct sum_space * space , const char * attr);
void sum_clear(struct sum_space * space , int module);
void sum_result_clear(struct sum_space * space , int module);
void sum_print(struct sum_space * space, int module);
#endif
