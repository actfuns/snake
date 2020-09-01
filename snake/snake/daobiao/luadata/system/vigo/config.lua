-- ./excel/system/vigo/vigo.xlsx
return {

    [1] = {
        cost = 150,
        formula = "SLV*350+56000",
        grade_limit = 35,
        grid_cost = {0, 0, 35, 50},
        grid_limit = 4,
        icon = "h7_tongqian",
        id = 1,
        name = "银币",
        sub_icon = "10003",
        time = 90,
        type = "silver",
    },

    [2] = {
        cost = 150,
        formula = "3500+SLV^2*0.7+grade^2*0.7+grade*17.5",
        grade_limit = 35,
        grid_cost = {0, 0, 35, 50},
        grid_limit = 4,
        icon = "h7_jingyan_4",
        id = 2,
        name = "经验",
        sub_icon = "10004",
        time = 90,
        type = "exp",
    },

    [3] = {
        cost = 150,
        formula = "SLV*0.35+56",
        grade_limit = 37,
        grid_cost = {0, 0, 35, 50},
        grid_limit = 4,
        icon = "h7_xiulian_2",
        id = 3,
        name = "修炼",
        sub_icon = "10016",
        time = 90,
        type = "expert",
    },

}
