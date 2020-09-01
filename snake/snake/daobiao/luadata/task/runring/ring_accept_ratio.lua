-- ./excel/task/runring/runring_config.xlsx
return {

    [1] = {
        accept_task_ratio = {{["ratio"] = 100, ["tasktype"] = 1}},
        id = 1,
        ring_lower = 1,
        ring_upper = 1,
    },

    [2] = {
        accept_task_ratio = {{["ratio"] = 20, ["tasktype"] = 1}, {["ratio"] = 30, ["tasktype"] = 2}, {["ratio"] = 25, ["tasktype"] = 3}, {["ratio"] = 25, ["tasktype"] = 4}},
        id = 2,
        ring_lower = 2,
        ring_upper = 99,
    },

    [3] = {
        accept_task_ratio = {{["ratio"] = 10, ["tasktype"] = 1}, {["ratio"] = 40, ["tasktype"] = 2}, {["ratio"] = 25, ["tasktype"] = 3}, {["ratio"] = 25, ["tasktype"] = 4}},
        id = 3,
        ring_lower = 100,
        ring_upper = 199,
    },

    [4] = {
        accept_task_ratio = {{["ratio"] = 30, ["tasktype"] = 2}, {["ratio"] = 40, ["tasktype"] = 3}, {["ratio"] = 30, ["tasktype"] = 4}},
        id = 4,
        ring_lower = 199,
        ring_upper = 200,
    },

}
