-- ./excel/tmp/huodong/orgwar/config.xlsx
return {

    [1] = {
        action_point = "lv*30+600",
        attack_cost_point = "math.min(1000,60*size)",
        barrage_send = 1,
        barrage_show = 1,
        enemy_win_announce = "{[5]=3004,[6]=3005,[7]=3006}",
        friend_win_announce = "{[5]=3007,[6]=3008,[7]=3009}",
        gold_box_num = "math.min(num,(15+num//2))",
        in_scene_org_score = "math.floor(cnt*5)",
        in_scene_war_score = "math.floor(cnt*5)",
        join_time_limit = 48,
        leave_org_limit = 0,
        lose_limit = 1000,
        lose_org_cash = 1000000,
        lose_org_prestige = "1000",
        lose_org_score = "math.floor(friend_cnt*15)",
        lose_serial_factor = "{[5]=30,[6]=35,[7]=40,[8]=45,[9]=50}",
        lose_sub_point = 3000,
        lose_war_score = 15,
        silver_box_num = "math.min(num,(15+num//2))",
        teamui_timeout = 3,
        win_org_cash = 2000000,
        win_org_prestige = "2000",
        win_org_score = "math.floor(enemy_cnt*60)",
        win_serial_factor = "{[1]=1,[2]=1,[3]=1,[4]=1,[5]=1.5,[6]=1.5,[7]=1.5,[8]=1.8,[9]=1.8,[10]=2}",
        win_war_score = "math.floor(enemy_cnt*60/friend_cnt*winner_factor+loser_factor)",
    },

}
