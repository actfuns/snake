--import module

local serverinfo = import(lualib_path("public.serverinfo"))

URLDEMI = {
    prefix = "/demisdk",
    dev_prefix = "/demisdkdev",
    url = {
        login_verify = "/v1/sdkc/integration/verify.json",
        pre_pay = "/v1/sdkc/integration/prePay.json",
    }
}

XGPUSH = {
    prefix = "/xgpush",
    url = {
        single_account = "/v2/push/single_account",
    }
}

ADAPI = {
    prefix = "/adapi",
    dev_prefix = "/devadapi",
    url = {
        adapi = "/log",
    }
}

function get_out_host()
    return serverinfo.get_out_host()
end

function get_demi_url(key)
    local sPrefix
    if serverinfo.DEMI_SDK.pro_env then
        sPrefix = URLDEMI.prefix
    else
        sPrefix = URLDEMI.dev_prefix
    end
    local sUrl = URLDEMI.url[key]
    return sPrefix..sUrl
end

function get_xg_url(key)
    return XGPUSH.prefix..XGPUSH.url[key]
end

function get_adapi_url(key)
    local sPrefix
    if serverinfo.DEMI_SDK.pro_env then
        sPrefix = ADAPI.prefix
    else
        sPrefix = ADAPI.dev_prefix
    end
    return sPrefix..ADAPI.url[key]
end

