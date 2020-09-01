-- ./excel/huodong/biwu/npc.xlsx
return {

    ["win"] = {
        exp = "(2917+500*lv)*wincnt",
        id = "win",
        point = "(50+30*lv)*wincnt*score",
        silver = "(8000+50*lv)*wincnt",
        summexp = "0.5*(2917+500*lv)*wincnt",
    },

    ["fail"] = {
        exp = "0.5*(2917+500*lv)*wincnt",
        id = "fail",
        point = "5",
        silver = "0.5*(8000+50*lv)*wincnt",
        summexp = "0.25*(2917+500*lv)*wincnt",
    },

}
