-- ./excel/viewdefine.xlsx
return {

    ["伙伴"] = {
        cls_name = "CPartnerMainView",
        id = 1,
        open_sys = "PARTNER_SYS",
        short_name = "Partner",
        sys_name = "伙伴",
        tab_list = {{["tab_name"] = "属性", ["tab_ename"] = "Recruit", ["tab_id"] = 1}, {["tab_name"] = "布阵", ["tab_ename"] = "Lineup", ["tab_id"] = 2}},
    },

    ["技能"] = {
        cls_name = "CSkillMainView",
        id = 2,
        open_sys = "SKILL_SYS",
        short_name = "Skill",
        sys_name = "技能",
        tab_list = {{["tab_name"] = "被动技能", ["tab_ename"] = "Passive", ["tab_id"] = 2}, {["tab_name"] = "主动技能", ["tab_ename"] = "School", ["tab_id"] = 1}, {["tab_name"] = "修炼技能", ["tab_ename"] = "Cultivation", ["tab_id"] = 3}, {["tab_name"] = "帮派技能", ["tab_ename"] = "Org", ["tab_id"] = 4}, {["tab_name"] = "剧情技能", ["tab_ename"] = "Talisman", ["tab_id"] = 5}, {["tab_name"] = "情缘技能", ["tab_ename"] = "QingYuan", ["tab_id"] = 6}},
    },

    ["排行榜"] = {
        cls_name = "CRankListView",
        id = 3,
        open_sys = "RANK_SYS",
        short_name = "Rank",
        sys_name = "排行榜",
        tab_list = {},
    },

    ["打造"] = {
        cls_name = "CForgeMainView",
        id = 4,
        open_sys = "EQUIP_SYS",
        short_name = "Forge",
        sys_name = "打造",
        tab_list = {{["tab_name"] = "打造", ["tab_ename"] = "Forge", ["tab_id"] = 1}, {["tab_name"] = "强化", ["tab_ename"] = "Strengthen", ["tab_id"] = 2}, {["tab_name"] = "洗炼", ["tab_ename"] = "Wash", ["tab_id"] = 3}, {["tab_name"] = "附魂", ["tab_ename"] = "Attach", ["tab_id"] = 4}, {["tab_name"] = ""}, {["tab_name"] = "镶嵌", ["tab_ename"] = "Inlay", ["tab_id"] = 5}},
    },

    ["帮派申请"] = {
        cls_name = "CJoinOrgView",
        id = 5,
        open_sys = "ORG_SYS",
        short_name = "JoinOrg",
        sys_name = "帮派申请",
        tab_list = {},
    },

    ["帮派"] = {
        cls_name = "COrgInfoView",
        id = 6,
        open_sys = "ORG_SYS",
        short_name = "OrgInfo",
        sys_name = "帮派",
        tab_list = {{["tab_name"] = "信息", ["tab_ename"] = "Info", ["tab_id"] = 1}, {["tab_name"] = "成员", ["tab_ename"] = "Member", ["tab_id"] = 2}, {["tab_name"] = "建筑", ["tab_ename"] = "Building", ["tab_id"] = 3}, {["tab_name"] = "福利", ["tab_ename"] = "Welfare", ["tab_id"] = 4}},
    },

    ["竞技场"] = {
        cls_name = "CJjcMainNewView",
        id = 7,
        open_sys = "JJC_SYS",
        short_name = "Jjc",
        sys_name = "竞技场",
        tab_list = {},
    },

    ["聊天"] = {
        cls_name = "CChatMainView",
        id = 8,
        open_sys = "",
        short_name = "Chat",
        sys_name = "聊天",
        tab_list = {},
    },

    ["背包"] = {
        cls_name = "CItemMainView",
        id = 9,
        open_sys = "",
        short_name = "Item",
        sys_name = "背包",
        tab_list = {{["tab_name"] = "包裹", ["tab_ename"] = "Bag", ["tab_id"] = 1}, {["tab_name"] = "仓库", ["tab_ename"] = "WH", ["tab_id"] = 2}, {["tab_name"] = "炼化", ["tab_ename"] = "Refine", ["tab_id"] = 3}},
    },

    ["商城"] = {
        cls_name = "CNpcShopMainView",
        id = 10,
        open_sys = "",
        short_name = "NpcShop",
        sys_name = "商城",
        tab_list = {{["tab_name"] = "商店", ["tab_ename"] = "Shop", ["tab_id"] = 1}, {["tab_name"] = "积分", ["tab_ename"] = "Score", ["tab_id"] = 2}, {["tab_name"] = "充值", ["tab_ename"] = "Recharge", ["tab_id"] = 3}},
    },

    ["好友"] = {
        cls_name = "CFriendInfoView",
        id = 11,
        open_sys = "",
        short_name = "Friend",
        sys_name = "好友",
        tab_list = {},
    },

    ["交易所"] = {
        cls_name = "CEcononmyMainView",
        id = 12,
        open_sys = "",
        short_name = "Econonmy",
        sys_name = "交易所",
        tab_list = {{["tab_name"] = "商会", ["tab_ename"] = "Guild", ["tab_id"] = 1}, {["tab_name"] = "摆摊", ["tab_ename"] = "Stall", ["tab_id"] = 2}, {["tab_name"] = "拍卖行", ["tab_ename"] = "Auction", ["tab_id"] = 3}},
    },

    ["人物属性"] = {
        cls_name = "CAttrMainView",
        id = 13,
        open_sys = "",
        short_name = "Attr",
        sys_name = "人物属性",
        tab_list = {{["tab_name"] = "属性", ["tab_ename"] = "Attr", ["tab_id"] = 1}, {["tab_name"] = "加点", ["tab_ename"] = "Point", ["tab_id"] = 2}, {["tab_name"] = "外观", ["tab_ename"] = "Waiguan", ["tab_id"] = 3}},
    },

    ["宠物属性"] = {
        cls_name = "CSummonMainView",
        id = 14,
        open_sys = "SUMMON_SYS",
        short_name = "Summon",
        sys_name = "宠物属性",
        tab_list = {{["tab_name"] = "属性", ["tab_ename"] = "Property", ["tab_id"] = 1}, {["tab_name"] = "炼妖", ["tab_ename"] = "Adjust", ["tab_id"] = 2}},
    },

    ["任务"] = {
        cls_name = "CTaskMainView",
        id = 15,
        open_sys = "",
        short_name = "Task",
        sys_name = "任务",
        tab_list = {{["tab_name"] = "当前任务", ["tab_ename"] = "Current", ["tab_id"] = 1}, {["tab_name"] = "可接任务", ["tab_ename"] = "Accept", ["tab_id"] = 2}, {["tab_name"] = "剧情", ["tab_ename"] = "Story", ["tab_id"] = 3}},
    },

    ["队伍"] = {
        cls_name = "CTeamMainView",
        id = 16,
        open_sys = "",
        short_name = "Team",
        sys_name = "队伍",
        tab_list = {{["tab_name"] = "队伍", ["tab_ename"] = "Team", ["tab_id"] = 1}, {["tab_name"] = "申请", ["tab_ename"] = "Apply", ["tab_id"] = 2}},
    },

    ["日程"] = {
        cls_name = "CScheduleMainView",
        id = 17,
        open_sys = "SCHEDULE",
        short_name = "schedule",
        sys_name = "日程",
        tab_list = {},
    },

    ["挂机"] = {
        cls_name = "CAutoPatrolView",
        id = 18,
        open_sys = "",
        short_name = "autopatrol",
        sys_name = "挂机",
        tab_list = {},
    },

    ["徽章"] = {
        cls_name = "CBadgeView",
        id = 19,
        open_sys = "BADGE",
        short_name = "badge",
        sys_name = "徽章",
        tab_list = {},
    },

    ["坐骑"] = {
        cls_name = "CHorseMainView",
        id = 20,
        open_sys = "RIDE_SYS",
        short_name = "horse",
        sys_name = "坐骑",
        tab_list = {{["tab_name"] = "属性", ["tab_ename"] = "attr", ["tab_id"] = 1}, {["tab_name"] = "升级", ["tab_ename"] = "Upgrade", ["tab_id"] = 2}, {["tab_name"] = "图鉴", ["tab_ename"] = "detail", ["tab_id"] = 3}},
    },

    ["异宝"] = {
        cls_name = "CYibaoMainView",
        id = 21,
        open_sys = "YIBAO",
        short_name = "yibao",
        sys_name = "异宝",
        tab_list = {},
    },

    ["合成"] = {
        cls_name = "CItemComposeView",
        id = 22,
        open_sys = "",
        short_name = "ItemCompose",
        sys_name = "合成",
        tab_list = {},
    },

    ["寻龙令"] = {
        cls_name = "CTreasureMatView",
        id = 23,
        open_sys = "",
        short_name = "TreasureMat",
        sys_name = "寻龙令",
        tab_list = {},
    },

    ["福利"] = {
        cls_name = "CWelfareView",
        id = 24,
        open_sys = "",
        short_name = "Welfare",
        sys_name = "福利",
        tab_list = {},
    },

    ["活力使用"] = {
        cls_name = "CAttrSkillQuickMakeView",
        id = 25,
        open_sys = "",
        short_name = "AttrSkillQuickMake",
        sys_name = "活力使用",
        tab_list = {},
    },

    ["防具商店"] = {
        cls_name = "CNpcEquipShopView",
        id = 26,
        open_sys = "STORE_SYS_201",
        short_name = "EquipShop",
        sys_name = "防具商店",
        tab_list = {},
    },

    ["武器商店"] = {
        cls_name = "CNpcWeaponShopView",
        id = 27,
        open_sys = "STORE_SYS_202",
        short_name = "WeaponShop",
        sys_name = "武器商店",
        tab_list = {},
    },

    ["药店"] = {
        cls_name = "CNpcMedicineShopView",
        id = 28,
        open_sys = "STORE_SYS_203",
        short_name = "MedicineShop",
        sys_name = "药店",
        tab_list = {},
    },

    ["神器"] = {
        cls_name = "CArtifactMainView",
        id = 29,
        open_sys = "ARTIFACT",
        short_name = "Artifact",
        sys_name = "神器",
        tab_list = {{["tab_name"] = "神器", ["tab_ename"] = "main", ["tab_id"] = 1}, {["tab_name"] = "强化", ["tab_ename"] = "qh", ["tab_id"] = 2}, {["tab_name"] = "器灵", ["tab_ename"] = "Qiling", ["tab_id"] = 3}, {["tab_name"] = "图鉴", ["tab_ename"] = "Tujian", ["tab_id"] = 4}},
    },

    ["羽翼"] = {
        cls_name = "CWingMainView",
        id = 30,
        open_sys = "WING",
        short_name = "Wing",
        sys_name = "羽翼",
        tab_list = {{["tab_name"] = "属性", ["tab_ename"] = "Attr", ["tab_id"] = 1}, {["tab_name"] = "幻化", ["tab_ename"] = "Huanhua", ["tab_id"] = 2}},
    },

    ["法宝"] = {
        cls_name = "CFaBaoView",
        id = 31,
        open_sys = "FABAO",
        short_name = "Fabao",
        sys_name = "法宝",
        tab_list = {{["tab_name"] = "佩戴", ["tab_ename"] = "Wear", ["tab_id"] = 1}, {["tab_name"] = "培养", ["tab_ename"] = "Cultivate", ["tab_id"] = 2}, {["tab_name"] = "觉醒", ["tab_ename"] = "Awaken", ["tab_id"] = 3}},
    },

    ["0元礼包"] = {
        cls_name = "CZeroBuyView",
        id = 32,
        open_sys = "ZEROYUAN",
        short_name = "ZeroBuy",
        sys_name = "0元礼包",
        tab_list = {{["tab_name"] = "橙装", ["tab_ename"] = "Chen", ["tab_id"] = 1}, {["tab_name"] = "外观", ["tab_ename"] = "Waiguan", ["tab_id"] = 2}, {["tab_name"] = "飞行", ["tab_ename"] = "Fly", ["tab_id"] = 3}},
    },

}
