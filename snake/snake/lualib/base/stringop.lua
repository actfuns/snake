
function split_string(s, rep, f, bReg)
    assert(rep ~= '')
    local lst = {}
    if #s > 0 then
        local bPlain
        if bReg then
            bPlain = false
        else
            bPlain = true
        end

        local iField, iStart = 1, 1
        local iFirst, iLast = string.find(s, rep, iStart, bPlain)
        while iFirst do
            lst[iField] = string.sub(s, iStart, iFirst - 1)
            iField = iField + 1
            iStart = iLast + 1
            iFirst, iLast = string.find(s, rep, iStart, bPlain)
        end
        lst[iField] = string.sub(s, iStart)

        if f then
            for k, v in ipairs(lst) do
                lst[k] = f(v)
            end
        end
    end
    return lst
end

function index_string(s, i)
    local iLen = #s
    if i > iLen or i < 1 then
        return
    end
    return string.char(s:byte(i))
end

local fm = {}
function formula_string(s, m)
    local f = fm[s]
    if f then
        return f(m)
    else
        f = load(string.format([[
            return function (m)
                for k, v in pairs(m) do
                    _ENV[k] = v
                end

                local __r = (%s)

                for k, v in pairs(m) do
                    _ENV[k] = nil
                end
                
                return __r
            end]], s), s, "bt", {pairs = pairs,math=math})()
        fm[s] = f
        return f(m)
    end
end

function trim(s, p)
    p = p or " "
    local pl = string.format("^[%s]*(.-)[%s]*$", p, p)
    return string.gsub(s, pl, "%1")
end
