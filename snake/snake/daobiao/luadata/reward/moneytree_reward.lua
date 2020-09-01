-- ./excel/reward/moneytree.xlsx
return {

    [1001] = {
        exp = "(lv*90+270)*(1+killcnt_10011*2/100+killcnt_10015*2/100)",
        gold = "(lv+200)*(1+killcnt_10016*10/100)",
        id = 1001,
        item = {1001},
        item_ratio = "(killcnt_10018*5/100+0.2)*100",
        partnerexp = "0",
        ride_exp = 60,
        silver = "(1000+200*lv)*(1+killcnt_10015*10/100)",
        strength_stone_ratio = "(killcnt_10017*5/100+0.3)*100",
        strength_stone_reward = 1005,
        summexp = "lv*33+192",
    },

    [1002] = {
        exp = "(lv*150+450)*(1+killcnt_10011*2/100+killcnt_10015*2/100)",
        gold = "(lv+350)*(1+killcnt_20016*15/100)",
        id = 1002,
        item = {1002},
        item_ratio = "(killcnt_20018*10/100+0.2)*100",
        partnerexp = "0",
        ride_exp = 80,
        silver = "(1000+300*lv)*(1+killcnt_20015*15/100)",
        strength_stone_ratio = "(killcnt_20017*9/100+0.3)*100",
        strength_stone_reward = 1006,
        summexp = "lv*55+320",
    },

}
