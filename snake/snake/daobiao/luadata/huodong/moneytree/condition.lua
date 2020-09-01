-- ./excel/huodong/moneytree/condition.xlsx
return {

    [1] = {
        amount = "math.floor(online/3)+1",
        continue_time = 60,
        grade = 30,
        limitcnt = 1,
        org_cash = "math.floor(kill_cnt*1000)",
        org_prestige = "4",
        refresh_npc = "{[7001]=100,[7002]=0}",
        reward_max = 10,
        start_time = "0-0-0 20:30",
        tip_time_shift1 = -10,
        tip_time_shift2 = -5,
        week_days = {6},
    },

}
