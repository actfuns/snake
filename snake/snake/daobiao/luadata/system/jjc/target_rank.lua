-- ./excel/system/jjc/target_rank.xlsx
return {

    [1] = {
        diff = 1,
        random_idx = "1",
        rank = {1},
    },

    [2] = {
        diff = 1,
        random_idx = "1",
        rank = {2, 10},
    },

    [3] = {
        diff = 2,
        random_idx = "math.random(1,2)",
        rank = {11, 20},
    },

    [4] = {
        diff = 4,
        random_idx = "math.random(1,4)",
        rank = {21, 50},
    },

    [5] = {
        diff = 5,
        random_idx = "math.random(1,5)",
        rank = {51, 100},
    },

    [6] = {
        diff = 25,
        random_idx = "math.random(15,25)",
        rank = {101, 500},
    },

    [7] = {
        diff = 50,
        random_idx = "math.random(40,50)",
        rank = {501, 1000},
    },

    [8] = {
        diff = 200,
        random_idx = "math.random(150,200)",
        rank = {1001, 2000},
    },

    [9] = {
        diff = 500,
        random_idx = "math.random(400,500)",
        rank = {2001, 5000},
    },

    [10] = {
        diff = 600,
        random_idx = "math.random(500,600)",
        rank = {5001, 10000},
    },

}
