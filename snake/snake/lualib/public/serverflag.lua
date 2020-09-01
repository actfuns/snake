-- import module

INVITE_LIST = {
    ["pro_gs20001"] = 1,
}

CLOSE_GUIDE = {
    ["pro_gs20001"] = 1,
}

function is_open_invite()
    return INVITE_LIST[get_server_key()]
end

function is_close_guide()
    return CLOSE_GUIDE[get_server_key()]
end
