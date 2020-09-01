-- ./excel/reward/ghost.xlsx
return {

    [1001] = {
        exp = "(lv*40+120)*(ring+2)/3",
        gold = "0",
        id = 1001,
        item = {},
        partnerexp = "0",
        silver = "3000*(1+lv/100)*(1+ring/100)",
        summexp = "(lv*40+233)*(ring+2)/6",
    },

    [1002] = {
        exp = "0",
        gold = "0",
        id = 1002,
        item = {1002},
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

    [1003] = {
        exp = "0",
        gold = "0",
        id = 1003,
        item = {1002},
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

    [1004] = {
        exp = "(lv*40+120)*(ring+2)/3",
        gold = "0",
        id = 1004,
        item = {1003},
        partnerexp = "0",
        silver = "3000*(1+lv/100)*(1+ring/100)",
        summexp = "(lv*40+233)*(ring+2)/6",
    },

    [2001] = {
        exp = "0",
        gold = "0",
        id = 2001,
        item = {1004},
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

}
