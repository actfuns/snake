
PROXY_TYPE_ITEM = 1         --道具
PROXY_TYPE_SUMM = 2         --宠物

PROXY_STATUS_SHOW   = 1     --公示期
PROXY_STATUS_PRICE  = 2     --竞拍期
PROXY_STATUS_DOWN   = 3     --流拍
PROXY_STATUS_CASH   = 4     --可提现
PROXY_STATUS_REMOVE = 5     --删除对象
PROXY_STATUS_REWARD = 6     --竞价成功
PROXY_STATUS_FAIL   = 7     --出价失败
PROXY_STATUS_EMPTY  = 8     --空
PROXY_STATUS_MAX    = 9     --最大出价
PROXY_STATUS_ERROR  = 10    --竞价成功

PAGE_AMOUNT = 50            --每页显示数量
EXCHANGE_RATE = 1000        --元宝换金币

function PageRange(iPage)
    return (iPage-1)*PAGE_AMOUNT + 1, iPage*PAGE_AMOUNT
end
