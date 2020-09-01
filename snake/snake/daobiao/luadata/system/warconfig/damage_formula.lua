-- ./excel/system/warconfig/warconfig.xlsx
return {

    [1] = {
        formula = "math.floor(math.max(level*5+grade*2+50, level*4+grade*2+mag_attack-mag_defense))",
        key = "magdamage_formula",
    },

}
