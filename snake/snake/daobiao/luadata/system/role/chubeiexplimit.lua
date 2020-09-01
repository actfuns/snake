-- ./excel/system/role/currencylimit.xlsx
return {

    ["timelimit"] = {
        key = "timelimit",
        value = "72",
    },

    ["formula"] = {
        key = "formula",
        value = "math.floor((lv*381+1908)/60*math.min(72*60, disconnect/60))",
    },

}
