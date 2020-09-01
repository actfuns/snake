#ifndef _SUM_H
#define _SUM_H

#include <stdint.h>
#include <stddef.h>
#include <math.h>

// lua层同步定义
#define PLAYER_ATTR_CNT 30
#define PMO_CNT 17

#define PMO_RESULT_BEGIN 0
#define PMO_RESULT_END 2

// 一级属性索引
#define FIRST_ATTR_BEGIN 0
#define FIRST_ATTR_END 4

// 一级属性影响属性索引
#define FIRST_EFFECT_BEGIN 5
#define FIRST_EFFECT_END 11

#define KEY_MAX_SIZE 25

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
} psum_modules;

// 有序
static const char attrarray[PLAYER_ATTR_CNT][KEY_MAX_SIZE] = {"physique","strength","magic","endurance","agility",\
"max_hp","max_mp","phy_attack","phy_defense","mag_attack","mag_defense","speed","cure_power",\
"seal_ratio","res_seal_ratio","phy_critical_ratio","res_phy_critical_ratio","mag_critical_ratio",\
"res_mag_critical_ratio","critical_multiple","res_phy_defense_ratio","res_mag_defense_ratio",\
"mag_damage_add","phy_damage_add","hit_ratio","hit_res_ratio","phy_hit_ratio","phy_hit_res_ratio",\
"mag_hit_ratio","mag_hit_res_ratio"};

struct psum_space;

struct psum_space * psum_create();
void psum_release(struct psum_space *);

int psum_getattrindex(const char * attr);
void psum_grade_effect(struct psum_space * space);
void psum_attr_effect(struct psum_space * space, const uint8_t attr);
bool psum_ismoduleadd(uint8_t module);
bool psum_ismoduleratio(uint8_t module);

int psum_update(struct psum_space * space , const char * attrkey ,uint8_t module, double value,bool add);
void psum_setscore(struct psum_space * space , double value);
void psum_setgrade(struct psum_space * space , int value);

double psum_getbaseattr(struct psum_space * space , const uint8_t attr);
double psum_getbaseratio(struct psum_space * space , const uint8_t attr);
double psum_getattradd(struct psum_space * space , const uint8_t attr);
double psum_getscore(struct psum_space * space );
double psum_getgrade(struct psum_space * space );

double psum_find(struct psum_space * space , const uint8_t attr, uint8_t module);

void psum_clear(struct psum_space * space , uint8_t module);
void psum_result_clear(struct psum_space * space , uint8_t module);

void psum_print(struct psum_space * space , uint8_t module);
#endif
