local gamedefines = import(lualib_path("public.gamedefines"))

RIDE_SCHOOL_KEY = {
    [gamedefines.PLAYER_SCHOOL.SHUSHAN] = "shushan",
    [gamedefines.PLAYER_SCHOOL.JINSHAN] = "jinshan",
    [gamedefines.PLAYER_SCHOOL.XINGXIU] = "xingxiu",
    [gamedefines.PLAYER_SCHOOL.YAOCHI] = "yaochi",
    [gamedefines.PLAYER_SCHOOL.QINGSHAN] = "qingshan",
    [gamedefines.PLAYER_SCHOOL.YAOSHEN] = "yaoshen",
}

SKILL_TYPE = {
    BASE_SKILL = 0,
    ADVANCE_SKILL = 1,
    FINAL_SKILL = 2,
    TALENT_SKILL = 3,
}

BASE_SKILL_NUM = 6
FINAL_SKILL_NUM = 1

WENSHI_MAX_POS = 3
CONTROL_SUMMON = 2