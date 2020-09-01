#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <stdlib.h>
#include <gdsl/gdsl_types.h>
#include <gdsl/gdsl_hash.h>

#include "skynet_malloc.h"
#include "sum.h"

#define SUM_HASH_SIZE 50
#define SUM_LIST_SIZE 2

struct _my_attr
{
	char* key;
	double value[MO_CNT];
};

typedef struct _my_attr* my_attr;

struct sum_space {
	sum_Alloc alloc;
	void* alloc_ud;
	gdsl_hash_t table;

	my_attr insobj;
};

static void
sum_debug_print(const char* s) {
    FILE *f = fopen("sum_debug.log", "a");
    if (f == NULL)
        return;
    fprintf(f, "debug: %s\n", s);
    fflush(f);
    fclose(f);
}

static void
my_attr_printf (gdsl_element_t e, FILE* file, gdsl_location_t location, void* d)
{
    my_attr s = (my_attr) e;
    int module = *(int *)d;
    FILE *f = fopen("sum_debug.log", "a");
    if (f == NULL)
        return;
    fprintf (f, "debug: %d %s %f\n", module, s->key,s->value[module]);
    fflush(f);
    fclose(f);
}

void
sum_print(struct sum_space * space, int module){
	gdsl_hash_write (space->table, my_attr_printf, stdout, &module);
}

static gdsl_element_t
my_attr_alloc (void* d)
{
	my_attr e = (my_attr) skynet_malloc(sizeof (struct _my_attr));
	if (e == NULL)
	{
		return NULL;
	}
	my_attr tmp = (my_attr)d;
	int i = 0;
	for (; i < MO_CNT; i++) {
		e->value[i] = tmp->value[i];
	}
	e->key = strdup ((char*) tmp->key);

	return (gdsl_element_t) e;
}

static void
my_attr_free (gdsl_element_t e)
{
	my_attr s = (my_attr) e;
	skynet_free(s->key);
	skynet_free(s);
}

static const char*
my_attr_key (gdsl_element_t e)
{
	my_attr s = (my_attr) e;
	return s->key;
}

static gdsl_hash_t
sum_table_new() {
	gdsl_hash_t tmpbase = gdsl_hash_alloc("sum", my_attr_alloc, my_attr_free, my_attr_key, NULL, SUM_HASH_SIZE);
	gdsl_hash_modify(tmpbase,SUM_HASH_SIZE,SUM_LIST_SIZE);
	gdsl_hash_flush(tmpbase);
	return tmpbase;
}

struct sum_space *
sum_create(sum_Alloc alloc, void *ud) {
	struct sum_space *space = alloc(ud, NULL, sizeof(*space));
	space->alloc = alloc;
	space->alloc_ud = ud;
	space->insobj = alloc(ud,NULL,sizeof(struct _my_attr));
	space->table = sum_table_new();
	return space;
}

void
sum_attr_effect(struct sum_space * space, const char *attr){
	if ( strcmp(attr,"grade") == 0 ){
		sum_result_set(space,MO_ATTR_POINT,"max_mp",-1);
		sum_result_set(space,MO_ATTR_POINT,"max_hp",-1);
	}
	else if ( strcmp(attr,"physique") == 0|| strcmp(attr,"magic") == 0\
		||strcmp(attr,"strength") == 0||strcmp(attr,"endurance") == 0\
		||strcmp(attr,"agility") == 0) {
		sum_result_set(space,MO_ATTR_POINT,"max_hp",-1);
		sum_result_set(space,MO_ATTR_POINT,"mag_attack",-1);
		sum_result_set(space,MO_ATTR_POINT,"mag_defense",-1);
		sum_result_set(space,MO_ATTR_POINT,"speed",-1);
		sum_result_set(space,MO_ATTR_POINT,"phy_attack",-1);
		sum_result_set(space,MO_ATTR_POINT,"phy_defense",-1);
	}
}

void
sum_update(struct sum_space * space , int module, const char * attr, double value, bool add){
	my_attr insertone = NULL;
	if (module > MO_CNT || module == MO_ATTR_ADD || module == MO_ATTR_BASE_R || module == MO_ATTR_POINT) {
		sum_debug_print("ERROR: sum_update module err failed!");
		return;
	}

	insertone = (my_attr)gdsl_hash_search(space->table,attr);
	if (insertone == NULL) {
		insertone = space->insobj;
		insertone->key = strdup ((char*) attr);
		int i = 0;
		for (;i<MO_CNT;i++) {
			if (i == MO_ATTR_ADD || i == MO_ATTR_BASE_R || i == MO_ATTR_POINT)
				insertone->value[i] = -1;
			else
				insertone->value[i] = 0;
		}
		insertone->value[module] = value;
		insertone = gdsl_hash_insert(space->table, (void*) insertone);
		if (insertone == NULL) {
			sum_debug_print("ERROR: sum_update failed!");
		}
	} else {
		if (add)
			insertone->value[module] = insertone->value[module] + value;
		else
			insertone->value[module] = value;
	}

	if (module == MO_SKILL_MGR_R || module == MO_EQUIP_MGR_R || module == MO_RIDE_MGR_R || module == MO_TITLE_MGR_R || module == MO_FABAO_MGR_R) {
		sum_result_set(space,MO_ATTR_BASE_R,attr,-1);
	} else {
		sum_result_set(space,MO_ATTR_ADD,attr,-1);
	}
	sum_result_set(space,MO_ATTR_POINT,attr,-1);
	sum_attr_effect(space,attr);
}

void
sum_result_set(struct sum_space * space , int module, const char * attr, double value){
	my_attr insertone = NULL;
	if (module != MO_ATTR_ADD && module != MO_ATTR_BASE_R && module != MO_ATTR_POINT) {
		sum_debug_print("ERROR: sum_result_set module err failed!");
		return;
	}

	insertone = (my_attr)gdsl_hash_search(space->table, attr);
	if (insertone == NULL) {
		insertone = space->insobj;
		insertone->key = strdup ((char*) attr);
		int i = 0;
		for (;i<MO_CNT;i++) {
			if (i == MO_ATTR_ADD || i == MO_ATTR_BASE_R || i == MO_ATTR_POINT)
				insertone->value[i] = -1;
			else
				insertone->value[i] = 0;
		}
		insertone->value[module] = value;
		insertone = gdsl_hash_insert(space->table, (void*) insertone);
		if (insertone == NULL) {
			sum_debug_print("ERROR: sum_result_set failed!");
		}
	} else {
		insertone->value[module] = value;
	}
}

static int
clear_element(gdsl_element_t e, gdsl_location_t location, void* user_infos) {
	my_attr s = (my_attr) e;
	int* mp = (int*) user_infos;
	int i = 1;
	for (; i <= mp[0]; i++) {
		int module = mp[i];
		if (module < MO_CNT) {
			if (module == MO_ATTR_ADD || module == MO_ATTR_BASE_R || module == MO_ATTR_POINT)
				s->value[module] = -1;
			else
				s->value[module] = 0;
		}
	}
	fflush(stdout);
	return GDSL_MAP_CONT;
}

void
sum_clear(struct sum_space * space , int module) {
	if (module > MO_CNT || module == MO_ATTR_ADD || module == MO_ATTR_BASE_R || module == MO_ATTR_POINT) {
		sum_debug_print("ERROR: sum_clear module err failed!");
		return;
	}

	int mds[4] = {3, module, 0, 0};
	if (module == MO_SKILL_MGR_R || module == MO_EQUIP_MGR_R || module == MO_RIDE_MGR_R || module == MO_TITLE_MGR_R || module == MO_FABAO_MGR_R) {
		mds[2] = MO_ATTR_BASE_R;
	} else {
		mds[2] = MO_ATTR_ADD;
	}
	mds[3] = MO_ATTR_POINT;
	
	gdsl_hash_map(space->table, clear_element, mds);
}


void
sum_result_clear(struct sum_space * space , int module){
	if (module != MO_ATTR_ADD && module != MO_ATTR_BASE_R && module != MO_ATTR_POINT) {
		sum_debug_print("ERROR: sum_result_clear module err failed!");
		return;
	}

	int mds[2] = {1, module};
	gdsl_hash_map(space->table, clear_element, mds);
}

double
sum_find(struct sum_space * space , int module, const char * attr) {
	my_attr findone = NULL;
	if (module > MO_CNT || module == MO_ATTR_ADD || module == MO_ATTR_BASE_R || module == MO_ATTR_POINT) {
		sum_debug_print("ERROR: sum_find module err failed!");
		return 0;
	}
	
	findone = (my_attr)gdsl_hash_search(space->table, attr);
	if (findone != NULL)
	{
		return findone->value[module];
	}
	return 0;
}

double
sum_result_find(struct sum_space * space , int module, const char * attr) {
	my_attr findone = NULL;
	if (module != MO_ATTR_ADD && module != MO_ATTR_BASE_R && module != MO_ATTR_POINT) {
		sum_debug_print("ERROR: sum_result_find module err failed!");
		return -1;
	}
	
	findone = (my_attr)gdsl_hash_search(space->table, attr);
	if (findone != NULL)
	{
		return findone->value[module];
	}
	return -1;
}

double
sum_getattradd(struct sum_space * space , const char * attr){
	double result = sum_result_find(space,MO_ATTR_ADD,attr);
	if (result != -1 ) {
		return result;
	}
	result = 0;
	result = result + sum_find(space,MO_SKILL_MGR,attr);
	result = result + sum_find(space,MO_EQUIP_MGR,attr);
	result = result + sum_find(space,MO_RIDE_MGR,attr);
	result = result + sum_find(space,MO_PARTNER,attr);
	result = result + sum_find(space,MO_RIDE,attr);
	result = result + sum_find(space,MO_TOUXIAN,attr);
	result = result + sum_find(space,MO_TITLE_MGR,attr);
	result = result + sum_find(space,MO_FABAO_MGR,attr);
	sum_result_set(space,MO_ATTR_ADD,attr,result);
	return result;
}

double
sum_getbaseratio(struct sum_space * space , const char * attr) {
	double result = sum_result_find(space,MO_ATTR_BASE_R,attr);
	if (result != -1) {
		return result;
	}
	result = 0;
	result = result + sum_find(space,MO_SKILL_MGR_R,attr);
	result = result + sum_find(space,MO_EQUIP_MGR_R,attr);
	result = result + sum_find(space,MO_RIDE_MGR_R,attr);
	result = result + sum_find(space,MO_TITLE_MGR_R,attr);
	result = result + sum_find(space,MO_FABAO_MGR_R,attr);
	sum_result_set(space,MO_ATTR_BASE_R,attr,result);
	return result;
}

void
sum_release(struct sum_space *space) {
	gdsl_hash_free(space->table);

	space->alloc(space->alloc_ud, space->insobj, sizeof(struct _my_attr));
	space->alloc(space->alloc_ud, space, sizeof(*space));
}
