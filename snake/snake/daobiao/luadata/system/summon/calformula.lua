-- ./excel/system/summon/calformula.xlsx
return {

    ["max_hp"] = {
        attr = "max_hp",
        formula = "grade*health*0.0107289+physique*grow*0.00735",
    },

    ["max_mp"] = {
        attr = "max_mp",
        formula = "grade*20+magic*5+strength*5",
    },

    ["phy_attack"] = {
        attr = "phy_attack",
        formula = "grade*attack*0.00288+strength*grow*0.00184",
    },

    ["phy_defense"] = {
        attr = "phy_defense",
        formula = "grade*defense*0.003512+endurance*grow*0.00252",
    },

    ["mag_attack"] = {
        attr = "mag_attack",
        formula = "grade*mana*0.001188+magic*grow*0.00184",
    },

    ["mag_defense"] = {
        attr = "mag_defense",
        formula = "grade*mana*0.000371+physique*grow*0.000318+magic*grow*0.00085+strength*1.06+grow*0.00051+endurance*grow*0.00017",
    },

    ["speed"] = {
        attr = "speed",
        formula = "grade*speed*0.002191+agility*grow*0.00168",
    },

    ["phy_hit_ratio"] = {
        attr = "phy_hit_ratio",
        formula = "100+grade*0.5",
    },

    ["phy_hit_res_ratio"] = {
        attr = "phy_hit_res_ratio",
        formula = "5+grade*0.5",
    },

    ["mag_hit_ratio"] = {
        attr = "mag_hit_ratio",
        formula = "100",
    },

    ["mag_hit_res_ratio"] = {
        attr = "mag_hit_res_ratio",
        formula = "0",
    },

    ["phy_critical_ratio"] = {
        attr = "phy_critical_ratio",
        formula = "3",
    },

    ["res_phy_critical_ratio"] = {
        attr = "res_phy_critical_ratio",
        formula = "0",
    },

    ["mag_critical_ratio"] = {
        attr = "mag_critical_ratio",
        formula = "0",
    },

    ["res_mag_critical_ratio"] = {
        attr = "res_mag_critical_ratio",
        formula = "0",
    },

    ["seal_ratio"] = {
        attr = "seal_ratio",
        formula = "100",
    },

    ["res_seal_ratio"] = {
        attr = "res_seal_ratio",
        formula = "0",
    },

    ["cure_power"] = {
        attr = "cure_power",
        formula = "0",
    },

    ["skill_rate1"] = {
        attr = "skill_rate1",
        formula = "10",
    },

    ["skill_rate2"] = {
        attr = "skill_rate2",
        formula = "{70,30,15,10,10,10}",
    },

}
