-- import file

local res = require "base.res"

local serverinfo = import(lualib_path("public.serverinfo"))

---- 需要处理的
function get_channel_info()
    if serverinfo.is_h7d_server() then
        return res["daobiao"]["h7dchannel"]
    else
        return res["daobiao"]["demichannel"]
    end
end 

function get_same_channels(iChannel)
    if serverinfo.is_h7d_server() then
        return res["daobiao"]["h7dchannelgroup"][iChannel] or {iChannel}
    else
        return res["daobiao"]["channelgroup"][iChannel] or {iChannel}
    end
end
---- 需要处理的