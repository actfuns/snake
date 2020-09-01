--import module
local skynet = require "skynet"
local serverdefines = require "public.serverdefines"

local serverdesc = import(lualib_path("public.serverdesc"))

if get_server_cluster() == "dev" then
    IS_PRODUCTION_ENV = false
    CS_INFO = {
        ip = "127.0.0.1", domain = "devh7.cilugame.com", slave_db_ip = "127.0.0.1", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "127.0.0.1", domain = "devh7.cilugame.com"
    }
    ROUTER_IP = "127.0.0.1"
    GS_INFO = {
        ["dev_gs10001"] = {name = "开发服", http_host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "127.0.0.1",
            slave_db_port = 27017, client_host = "g101.h7.cilugame.com", area = 1},
    }
    OUT_HOST = "127.0.0.1:2001"
    DEMI_SDK = {
        pro_env = false, app_id = 3, app_key = "tYp6omSNSvkZVv6V", machine_id = 1
    }
    KS_INFO = {
        ["dev_ks101"] = {name = "跨服", host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "127.0.0.1", slave_db_port = 27017, client_host = "127.0.0.1",},
    }
elseif get_server_cluster() == "devd" then
    IS_PRODUCTION_ENV = false
    CS_INFO = {
        ip = "192.168.8.137", domain = "devh7d.demigame.com", slave_db_ip = "192.168.8.137", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "192.168.8.137", domain = "devh7d.demigame.com"
    }
    ROUTER_IP = "192.168.8.137"
    GS_INFO = {
        ["devd_gs10001"] = {name = "开发服", http_host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "192.168.8.137",
            slave_db_port = 27017, client_host = "devh7d.demigame.com", area = 1},
        ["devd_gs10002"] = {name = "调时间", http_host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "192.168.8.136",
            slave_db_port = 27017, client_host = "192.168.8.136",},
        ["devd_gs10003"] = {name = "客户端压测", http_host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "192.168.8.133",
            slave_db_port = 27017, client_host = "testh7.cilugame.com",},
    }
    OUT_HOST = "192.168.9.188:80"
    DEMI_SDK = {
        pro_env = false, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 1, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
    KS_INFO = {
        ["devd_ks101"] = {name = "跨服", host = "192.168.8.101", master_db_ip = "127.0.0.1", slave_db_ip = "127.0.0.1", slave_db_port = 27017, client_host = "devkuafuh7d.demigame.com",},
    }
elseif get_server_cluster() == "h7demu" then
    IS_PRODUCTION_ENV = false
    CS_INFO = {
        ip = "192.168.9.188", domain = "emuh7.demigame.com", slave_db_ip = "192.168.9.188", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "192.168.9.188", domain = "emuh7.demigame.com"
    }
    ROUTER_IP = "192.168.9.188"
    GS_INFO = {
        ["h7demu_gs10001"] = {name = "仿真服", http_host = "192.168.9.188", master_db_ip = "192.168.9.188", slave_db_ip = "192.168.9.188",
            slave_db_port = 27017, client_host = "192.168.1.19",}
    }
    KS_INFO = {
        ["h7demu_ks101"] = {name = "仿真服-跨服", http_host = "192.168.9.188", master_db_ip = "192.168.9.188", slave_db_ip = "192.168.9.188",
            slave_db_port = 27017, client_host = "192.168.1.19",}
    }
    OUT_HOST = "192.168.9.188:80"
    DEMI_SDK = {
        pro_env = false, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 2, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
elseif get_server_cluster() == "h7diosshenhe" then
    IS_PRODUCTION_ENV = true
    CS_INFO = {
        ip = "172.19.252.151", domain = "iosshenheh7d.demigame.com", slave_db_ip = "172.19.252.151", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "172.19.252.151", domain = "iosshenheh7d.demigame.com"
    }
    ROUTER_IP = "172.19.252.151"
    GS_INFO = {
        ["h7diosshenhe_gs10001"] = {name = "ios审核服", http_host = "172.19.252.151", master_db_ip = "172.19.252.151", slave_db_ip = "172.19.252.151",
            slave_db_port = 27017, client_host = "iosshenheh7d.demigame.com",},
    }
    OUT_HOST = "172.19.252.150:80"
    DEMI_SDK = {
        pro_env = true, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 4, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
elseif get_server_cluster() == "h7doutertest" then
    IS_PRODUCTION_ENV = true
    CS_INFO = {
        ip = "172.19.252.148", domain = "testh7d.demigame.com", slave_db_ip = "172.19.252.148", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "172.19.252.148", domain = "testh7d.demigame.com"
    }
    ROUTER_IP = "172.19.252.148"
    GS_INFO = {
        ["h7doutertest_gs10001"] = {name = "外网测试服", http_host = "172.19.252.148", master_db_ip = "172.19.252.148", slave_db_ip = "172.19.252.148",
            slave_db_port = 27017, client_host = "47.100.162.45",}
    }
    OUT_HOST = "172.19.252.150:80"
    DEMI_SDK = {
        pro_env = false, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 2, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
elseif get_server_cluster() == "h7dbusiness" then
    IS_PRODUCTION_ENV = false
    CS_INFO = {
        ip = "172.19.252.141", domain = "devh7d.demigame.com", slave_db_ip = "172.19.252.141", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "172.19.252.141", domain = "devh7d.demigame.com"
    }
    ROUTER_IP = "172.19.252.141"
    GS_INFO = {
        ["h7dbusiness_gs10001"] = {name = "商务服", http_host = "172.19.252.141", master_db_ip = "172.19.252.141", slave_db_ip = "172.19.252.141",
            slave_db_port = 27017, client_host = "47.100.195.150",}
    }
    OUT_HOST = "172.19.252.150:80"
    DEMI_SDK = {
        pro_env = false, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 1, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
elseif get_server_cluster() == "h7dpro" then
    IS_PRODUCTION_ENV = true
    CS_INFO = {
        ip = "172.19.252.143", domain = "csh7d.demigame.com", slave_db_ip = "172.19.252.123", slave_db_port = 27023
    }
    BS_INFO = {
        ip = "172.19.252.152", domain = "bsh7d.demigame.com"
    }
    ROUTER_IP = "172.19.252.143"
    GS_INFO = {
        ["h7dpro_gs10001"] = {name = "西湖映月", http_host = "172.19.252.144", master_db_ip = "172.19.252.144", slave_db_ip = "172.19.252.123", slave_db_port = 27022, client_host = "106.14.210.248",},
        -- ["h7dpro_gs10002"] = {name = "三潭印月", http_host = "172.19.252.156", master_db_ip = "172.19.252.156", slave_db_ip = "172.19.252.123", slave_db_port = 27024, client_host = "106.14.4.32",},
        ["h7dpro_gs10003"] = {name = "平湖秋月", http_host = "172.19.252.157", master_db_ip = "172.19.252.157", slave_db_ip = "172.19.252.123", slave_db_port = 27015, client_host = "47.101.42.196",},
        ["h7dpro_gs10004"] = {name = "曲院风荷", http_host = "172.19.252.172", master_db_ip = "172.19.252.172", slave_db_ip = "172.19.252.123", slave_db_port = 27016, client_host = "47.100.104.87",},
        ["h7dpro_gs10005"] = {name = "柳浪闻莺", http_host = "172.19.252.173", master_db_ip = "172.19.252.173", slave_db_ip = "172.19.252.123", slave_db_port = 27014, client_host = "47.101.54.132",},
        ["h7dpro_gs10006"] = {name = "断桥残雪", http_host = "172.19.252.174", master_db_ip = "172.19.252.174", slave_db_ip = "172.19.252.123", slave_db_port = 27013, client_host = "106.14.208.44",},
        ["h7dpro_gs10007"] = {name = "花港观鱼", http_host = "172.19.252.175", master_db_ip = "172.19.252.175", slave_db_ip = "172.19.252.123", slave_db_port = 27012, client_host = "106.14.170.166",},
        ["h7dpro_gs10008"] = {name = "苏堤春晓", http_host = "172.19.252.177", master_db_ip = "172.19.252.177", slave_db_ip = "172.19.252.123", slave_db_port = 27009, client_host = "47.100.240.198",},
        ["h7dpro_gs10009"] = {name = "雷峰夕照", http_host = "172.19.252.179", master_db_ip = "172.19.252.179", slave_db_ip = "172.19.252.123", slave_db_port = 27008, client_host = "139.224.111.50",},
        ["h7dpro_gs10010"] = {name = "双峰插云", http_host = "172.19.252.182", master_db_ip = "172.19.252.182", slave_db_ip = "172.19.252.123", slave_db_port = 27007, client_host = "139.224.239.34",},
        ["h7dpro_gs20001"] = {name = "梦回西湖", http_host = "172.19.252.176", master_db_ip = "172.19.252.176", slave_db_ip = "172.19.252.123", slave_db_port = 27011, client_host = "47.100.108.71",},
        ["h7dpro_gs90001"] = {name = "外网测试服", http_host = "172.19.252.148", master_db_ip = "172.19.252.148", slave_db_ip = "172.19.252.123", slave_db_port = 27021, client_host = "47.100.162.45",},
        ["h7dpro_gs90002"] = {name = "IOS审核服", http_host = "172.19.252.151", master_db_ip = "172.19.252.151", slave_db_ip = "172.19.252.123", slave_db_port = 27010, client_host = "iosshenheh7d.demigame.com",},
        ["h7dpro_gs90003"] = {name = "IOS审核服2", http_host = "172.19.252.180", master_db_ip = "172.19.252.180", slave_db_ip = "172.19.252.123", slave_db_port = 27005, client_host = "h7d-90003.demigame.com",},
    }

    KS_INFO = {
        ["h7dpro_ks101"] = {name = "跨服", master_db_ip = "172.19.252.181", slave_db_ip = "172.19.252.123", slave_db_port = 27006, client_host = "106.14.173.47",},
    }

    OUT_HOST = "172.19.252.150:80"
    DEMI_SDK = {
        pro_env = true, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 1, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
elseif get_server_cluster() == "h7dmerger" then
    IS_PRODUCTION_ENV = false
    CS_INFO = {
        ip = "127.0.0.1", domain = "mergeh7d.demigame.com", slave_db_ip = "127.0.0.1", slave_db_port = 27017
    }
    BS_INFO = {
        ip = "127.0.0.1", domain = "mergeh7d.demigame.com"
    }
    ROUTER_IP = "127.0.0.1"
    GS_INFO = {
        ["h7dmerger_gs10003"] = {name = "平湖秋月", http_host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "127.0.0.1", slave_db_port = 27017, client_host = "101.132.113.251", desc = serverdesc.SERVER_DESC.all},
        ["h7dmerger_gs10004"] = {name = "曲院风荷", http_host = "127.0.0.1", master_db_ip = "127.0.0.1", slave_db_ip = "127.0.0.1", slave_db_port = 27018, client_host = "101.132.113.251", desc = serverdesc.SERVER_DESC.all},
    }
    OUT_HOST = "127.0.0.1:80"
    DEMI_SDK = {
        pro_env = false, app_id = 6, app_key = "t7b7HKsCPgGcdnya", machine_id = 2, ad_key = "a23340f482af65fd16b1a5b84148e5a7",
    }
else
    assert(false, string.format("wrong server cluster %s", get_server_cluster()))
end

function get_cs_host()
    return CS_INFO["ip"]
end

function get_cs_domain()
    return CS_INFO["domain"]
end

function get_router_host()
    return ROUTER_IP
end

function get_out_host()
    return OUT_HOST
end

function get_gs_host(serverkey)
    if not GS_INFO[serverkey] then
        return
    end
    return string.format("%s:%d",GS_INFO[serverkey]["http_host"],GS_WEB_PORT)
end

function get_local_dbs()
    local host = "127.0.0.1"
    if is_cs_server() then
        host = CS_INFO["ip"]
    elseif is_bs_server() then
        host = BS_INFO["ip"]
    elseif is_ks_server() then
        host = KS_INFO[get_server_key()]["master_db_ip"]
    else
        host = GS_INFO[get_server_key()]["master_db_ip"]
    end
    local sUser = MONGO_USER
    local sPwd = MONGO_PWD
    return {
        game = {host=host, port=27017, username=sUser, password=sPwd},
        gamelog = {host=host, port=27017, username=sUser, password=sPwd},
        unmovelog = {host=host, port=27017, username=sUser, password=sPwd},
        backend = {host=host, port=27017, username=sUser, password=sPwd},
    }
end

function get_cs_slave_dbs()
    local sUser = MONGO_USER
    local sPwd = MONGO_PWD
    local slave_db_ip = CS_INFO["slave_db_ip"]
    local slave_db_port = CS_INFO["slave_db_port"]
    return {
        game = {host=slave_db_ip, port=slave_db_port, username=sUser, password=sPwd},
        gamelog = {host=slave_db_ip, port=slave_db_port, username=sUser, password=sPwd},
    }
end

function get_slave_dbs(serverkeys)
    serverkeys = serverkeys or list_combine(get_gs_key_list(), get_ks_key_list())
    local sUser = MONGO_USER
    local sPwd = MONGO_PWD

    local ret = {}
    for _, key in ipairs(serverkeys) do
        local info = GS_INFO[key] or KS_INFO[key]
        if info then
            local slave_db_ip = info["slave_db_ip"]
            local slave_db_port = info["slave_db_port"]
            local info = {
                game = {host=slave_db_ip, port=slave_db_port, username=sUser, password=sPwd},
                gamelog = {host=slave_db_ip, port=slave_db_port, username=sUser, password=sPwd},
                gameumlog = {host=slave_db_ip, port=slave_db_port, username=sUser, password=sPwd},
            }
            ret[key] = info
        end
    end
    return ret
end

function get_gs_key_list()
    return table_key_list(GS_INFO)
end

function get_gs_tag_list()
    local gs_list = {}
    for key, _ in pairs(GS_INFO) do
        table.insert(gs_list, get_server_tag(key))
    end
    return gs_list
end

function get_gs_info(serverkey)
    return GS_INFO[serverkey]
end

function get_server_name(serverkey)
    serverkey = serverkey or get_server_key()
    local info = GS_INFO[serverkey]
    if not info then
        return
    end
    return info.name
end

function get_ks_key_list()
    return table_key_list(KS_INFO or {})
end

function get_ks_info(serverkey)
    if KS_INFO then return KS_INFO[serverkey] end
end

function get_ks_host(serverkey)
    serverkey = serverkey or get_server_key()
    local mInfo = KS_INFO[serverkey]
    if not mInfo then return end

    return mInfo.client_host
end

function get_client_host(serverkey)
    serverkey = serverkey or get_server_key()
    local info = GS_INFO[serverkey]
    if not info then
        return
    end
    return info.client_host
end

local h7d_server = {
    devd = 1,
    h7diosshenhe = 1,
    h7dpro = 1,
    h7doutertest = 1,
    h7dbusiness = 1,
    h7demu = 1,
    h7dmerger = 1,
}

function is_h7d_server(serverkey)
    serverkey = serverkey or get_server_key()
    local server_cluster = get_server_cluster(serverkey)
    return h7d_server[server_cluster] and true or false
end

function is_h7d_merger(serverkey)
    serverkey = serverkey or get_server_key()
    local server_cluster = get_server_cluster(serverkey)
    return server_cluster == "h7dmerger"
end
