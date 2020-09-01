#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <stdlib.h>
#include <gdsl/gdsl_types.h>
#include <gdsl/gdsl_hash.h>

#include "skynet_malloc.h"
#include "psum.h"


struct psum_space {
	double score;
	int grade;
	double value[PLAYER_ATTR_CNT][PMO_CNT];
};

static void
psum_debug_print(const char* s) {
    FILE *f = fopen("psum_debug.log", "a");
    if (f == NULL)
        return;
    fprintf(f, "debug: %s\n", s);
    fflush(f);
    fclose(f);
}

static void
psum_init(struct psum_space *space){
	space->score = -1;
	space->grade = 0;
	memset(space->value,0,sizeof(space->value));
	int i=0;
	for(;i<PLAYER_ATTR_CNT;i++)
	{
		int j =PMO_RESULT_BEGIN;
		for(;j<=PMO_RESULT_END;j++)
			space->value[i][j] = -1;
	}
}

struct psum_space *
psum_create() {
	struct psum_space *space = skynet_malloc(sizeof(*space));
	psum_init(space);
	return space;
}

void
psum_release(struct psum_space *space) {
	skynet_free(space);
}

int
psum_update(struct psum_space * space , const char * attrkey ,uint8_t module, double value, bool add){
	int attr = psum_getattrindex(attrkey);
	if (attr == -1) 
		return -1;

	if (add)
		space->value[attr][module]=space->value[attr][module]+value;
	else
		space->value[attr][module]=value;

	if (module == MO_BASE){
		space->value[attr][MO_ATTR_POINT] = -1;
	}else if (psum_ismoduleadd(module)) {
		space->value[attr][MO_ATTR_ADD] = -1;
	}else if (psum_ismoduleratio(module)) {
		space->value[attr][MO_ATTR_BASE_R] = -1;
	}

	psum_attr_effect(space, attr);
	return 0;
}

int psum_getattrindex(const char * attr) {
	int i=0;
	for(;i<PLAYER_ATTR_CNT;i++){
		if (strcmp(attrarray[i], attr) == 0){
			break; 
		}
	}
	return i;
}

void psum_setscore(struct psum_space * space , double value){
	space->score = value;
}

double psum_getscore(struct psum_space * space){
	return space->score;
}

void psum_setgrade(struct psum_space * space, int value){
	space->grade = value;
	psum_grade_effect(space);
}

double psum_getgrade(struct psum_space * space){
	return space->grade;
}

void psum_grade_effect(struct psum_space * space){
	char * attrkey = "max_mp";
	uint8_t attr = psum_getattrindex(attrkey);
	space->value[attr][MO_ATTR_POINT] = -1;

	attrkey = "max_hp";
	attr = psum_getattrindex(attrkey);
	space->value[attr][MO_ATTR_POINT] = -1;
}

double psum_getbaseratio(struct psum_space * space , const uint8_t attr){
	if (space->value[attr][MO_ATTR_BASE_R] != -1){
		return space->value[attr][MO_ATTR_BASE_R];
	}
	double result = 0;
	result = result + space->value[attr][MO_SKILL_MGR_R];
	result = result + space->value[attr][MO_EQUIP_MGR_R];
	result = result + space->value[attr][MO_RIDE_MGR_R];
	result = result + space->value[attr][MO_TITLE_MGR_R];
	result = result + space->value[attr][MO_FABAO_MGR_R];
	space->value[attr][MO_ATTR_BASE_R] = result;
	return result;
}

double psum_getattradd(struct psum_space * space , const uint8_t attr){
	if (space->value[attr][MO_ATTR_ADD] != -1){
		return space->value[attr][MO_ATTR_ADD];
	}
	double result = 0;
	result = result + space->value[attr][MO_PARTNER];
	result = result + space->value[attr][MO_RIDE];
	result = result + space->value[attr][MO_TOUXIAN];
	result = result + space->value[attr][MO_SKILL_MGR];
	result = result + space->value[attr][MO_EQUIP_MGR];
	result = result + space->value[attr][MO_RIDE_MGR];
	result = result + space->value[attr][MO_TITLE_MGR];
	result = result + space->value[attr][MO_FABAO_MGR];
	space->value[attr][MO_ATTR_ADD] = result;
	return result;
}

double psum_getbaseattr(struct psum_space * space , const uint8_t attr){
	double result = floor(psum_find(space,attr,MO_BASE));
	return result;
}

double psum_find(struct psum_space * space , const uint8_t attr, uint8_t module){
	return space->value[attr][module];
}

void psum_attr_effect(struct psum_space * space, const uint8_t attr){
	if (FIRST_ATTR_BEGIN <= attr && attr <= FIRST_ATTR_END) {
		int i=FIRST_EFFECT_BEGIN;
		for(;i<=FIRST_EFFECT_END;i++)
			space->value[i][MO_ATTR_POINT] = -1;
	}
}

void psum_reset (struct psum_space * space, uint8_t module, bool cache) {
	int i=0;
	for(;i<PLAYER_ATTR_CNT;i++)
		if (cache)
			space->value[i][module] = -1;
		else
			space->value[i][module] = 0;
}

void psum_clear(struct psum_space * space , uint8_t module) {
	psum_reset(space,module,false);
	if (module == MO_BASE) {
		psum_reset(space,MO_ATTR_POINT,true);
	}else if (psum_ismoduleadd(module)) {
		psum_reset(space,MO_ATTR_ADD,true);
	}else if (psum_ismoduleratio(module)) {
		psum_reset(space,MO_ATTR_BASE_R,true);
	}
}

bool psum_ismoduleadd(uint8_t module){
	if (module == MO_PARTNER || module == MO_RIDE || module == MO_TOUXIAN \
		|| module == MO_SKILL_MGR || module == MO_EQUIP_MGR || module == MO_RIDE_MGR \
		|| module == MO_TITLE_MGR || module == MO_FABAO_MGR){
		return true;	
	}
	return false;
}
bool psum_ismoduleratio(uint8_t module){
	if (module == MO_SKILL_MGR_R || module == MO_EQUIP_MGR_R || module == MO_RIDE_MGR_R \
		|| module == MO_TITLE_MGR_R || module == MO_FABAO_MGR_R) {
		return true;
	}
	return false;
}

void psum_print(struct psum_space * space , uint8_t module){
	int i=0;
	char tmp[100];
	for(;i<PLAYER_ATTR_CNT;i++){
		sprintf(tmp, "i=%d value = %lf",i,space->value[i][module]);
		psum_debug_print(tmp);
	}

}

