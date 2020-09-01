-- ./excel/huodong/returngoldcoin/config.xlsx
return {

    ["part1"] = {
        formula = "math.floor(math.min(500,money)*10*2)",
        key = "part1",
    },

    ["part2"] = {
        formula = "math.floor(math.max(math.min(2000,money)-500,0)*10*1.5)",
        key = "part2",
    },

    ["part3"] = {
        formula = "math.floor(math.max(money-2000,0)*10)",
        key = "part3",
    },

    ["all"] = {
        formula = "math.floor(math.min(500,money)*10*2)+math.floor(math.max(math.min(2000,money)-500,0)*10*1.5)+math.floor(math.max(money-2000,0)*10)",
        key = "all",
    },

    ["goldcoin"] = {
        formula = "money*10",
        key = "goldcoin",
    },

    ["rplgoldcoin"] = {
        formula = "math.floor(math.min(500,money)*10*2)+math.floor(math.max(math.min(2000,money)-500,0)*10*1.5)+math.floor(math.max(money-2000,0)*10)-money*10",
        key = "rplgoldcoin",
    },

    ["half_rplgoldcoin"] = {
        formula = "math.floor((math.floor(math.min(500,money)*10*2)+math.floor(math.max(math.min(2000,money)-500,0)*10*1.5)+math.floor(math.max(money-2000,0)*10)-money*10)/2)",
        key = "half_rplgoldcoin",
    },

}
