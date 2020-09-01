-- ./excel/reward/orgwar.xlsx
return {

    [1001] = {
        exp = "lv*100+300",
        gold = "0",
        id = 1001,
        item = {},
        org_offer = "0",
        partnerexp = "0",
        silver = "lv*50+8000",
        summexp = "SLV*30+60",
    },

    [1002] = {
        exp = "400*lv+1200",
        gold = "0",
        id = 1002,
        item = {1001, 1005},
        org_offer = "20",
        partnerexp = "0",
        silver = "lv*130+25000",
        summexp = "SLV*60+240",
    },

    [1003] = {
        exp = "200*lv+600",
        gold = "0",
        id = 1003,
        item = {1002, 1006},
        org_offer = "10",
        partnerexp = "0",
        silver = "lv*60+12500",
        summexp = "SLV*30+120",
    },

    [1004] = {
        exp = "0",
        gold = "0",
        id = 1004,
        item = {1003},
        org_offer = "20",
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

    [1005] = {
        exp = "0",
        gold = "0",
        id = 1005,
        item = {1004},
        org_offer = "10",
        partnerexp = "0",
        silver = "0",
        summexp = "0",
    },

}
