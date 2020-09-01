-- ./excel/reward/runring.xlsx
return {

    [1001] = {
        exp = "((50+math.ceil(ring/10)*14)*lv+100)*(1+ring/10*0.05)",
        gold = "0",
        id = 1001,
        item = {},
        mail = 0,
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

    [1002] = {
        exp = "0",
        gold = "0",
        id = 1002,
        item = {1001},
        mail = 0,
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

    [1003] = {
        exp = "0",
        gold = "0",
        id = 1003,
        item = {1002},
        mail = 0,
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

    [2001] = {
        exp = "10+lv*3",
        gold = "0",
        id = 2001,
        item = {2001},
        mail = 0,
        partnerexp = "0",
        silver = "300+lv*2",
        summexp = "0",
    },

}
