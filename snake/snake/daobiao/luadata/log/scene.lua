-- ./excel/log/scene.xlsx
return {

    ["create"] = {
        explain = "创建场景",
        log_format = {["id"] = {["id"] = "id", ["desc"] = "场景id"}, ["mapid"] = {["id"] = "mapid", ["desc"] = "地图资源"}},
        subtype = "create",
    },

    ["remove"] = {
        explain = "删除场景",
        log_format = {["id"] = {["id"] = "id", ["desc"] = "场景id"}, ["mapid"] = {["id"] = "mapid", ["desc"] = "地图资源"}},
        subtype = "remove",
    },

}
