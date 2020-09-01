-- ./excel/huodong/hfdm/config.xlsx
return {

    [1] = {
        answer_left_judge_x = 12.24,
        answer_right_judge_x = 15.8,
        correct_rwd_tbl = 1001,
        countup_cnt = 5,
        countup_rwd_tbl = 2001,
        countup_rwd_times = 3,
        enter_pos_range = {["x1"] = 13.0, ["x2"] = 13.5, ["y1"] = 5.9, ["y2"] = 6.1},
        incorrect_rwd_tbl = 1002,
        jump_left_pos_range = {["x1"] = 3.9, ["x2"] = 7.9, ["y1"] = 5.0, ["y2"] = 6.7},
        jump_right_pos_range = {["x1"] = 19.5, ["x2"] = 23.3, ["y1"] = 4.5, ["y2"] = 7.7},
        prepare_sec = 60,
        ques_answer_sec = 25,
        ques_cnt = 30,
        ques_last_wait_sec = 60,
        ques_wait_sec = 5,
        score = "(costtime<5) and (100) or (100-costtime*0.3)",
    },

}
