local gamedefines = import(lualib_path("public.gamedefines"))


MARRY_TITLE_ID = {
    [gamedefines.SEX_TYPE.SEX_MALE] = 944,
    [gamedefines.SEX_TYPE.SEX_FEMALE] = 945,
}

DIVORCE_TYPE = {
    NOMAL = 0,
    FORCE = 1,    
}

DIVORCE_STATUS = {
    NONE = 0,
    SUBMIT = 1,    
    CONFIRM = 2,    
}

MARRY_ITEM_XT = 10148
MARRY_ITEM_YH = 10174

MARRY_MAPID = 101000
MARRY_XT_CNT_MOMENT = 20
MARRY_XT_NPC = 8237
PICK_XT_PRO_SEC = 1

MARRY_STATUS = {
    NONE = 0,
    ENGAGE = 1,     -- 订婚
    MARRY = 2       -- 结婚
}


SZ_OPEN_TIME = 3*24*3600



