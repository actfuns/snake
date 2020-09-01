-- ./excel/huodong/lingxi/configs.xlsx
return {

    ["worm"] = {
        id = "worm",
        no = 1,
        progress_text = "除虫中",
        progress_time = 3,
        qteid = 0,
        ques_cnt = 0,
        ques_correct_cnt = 0,
        reward_fail_tbl = 0,
        reward_succ_tbl = 100020,
        sec_per_ques = 0,
        timeout = 10,
    },

    ["water"] = {
        id = "water",
        no = 2,
        progress_text = "浇水中",
        progress_time = 3,
        qteid = 0,
        ques_cnt = 0,
        ques_correct_cnt = 0,
        reward_fail_tbl = 0,
        reward_succ_tbl = 100020,
        sec_per_ques = 0,
        timeout = 10,
    },

    ["heart"] = {
        id = "heart",
        no = 3,
        progress_text = "",
        progress_time = 0,
        qteid = 6,
        ques_cnt = 0,
        ques_correct_cnt = 0,
        reward_fail_tbl = 0,
        reward_succ_tbl = 100020,
        sec_per_ques = 0,
        timeout = 10,
    },

    ["question"] = {
        id = "question",
        no = 4,
        progress_text = "",
        progress_time = 0,
        qteid = 0,
        ques_cnt = 3,
        ques_correct_cnt = 3,
        reward_fail_tbl = 0,
        reward_succ_tbl = 100020,
        sec_per_ques = 10,
        timeout = 30,
    },

}
