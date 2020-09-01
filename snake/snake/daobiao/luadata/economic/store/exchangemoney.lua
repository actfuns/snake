-- ./excel/economic/store/store.xlsx
return {

    [3] = {
        gold = "value*100",
        goldcoin = "",
        moneytype = 3,
        silver = "value*(SLV*50+8000)",
    },

    [1] = {
        gold = "",
        goldcoin = "math.ceil(value/100)",
        moneytype = 1,
        silver = "",
    },

    [2] = {
        gold = "",
        goldcoin = "math.ceil(value/(SLV*50+8000))",
        moneytype = 2,
        silver = "",
    },

}
