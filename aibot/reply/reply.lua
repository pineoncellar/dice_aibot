msg_reply.aibot_good_mn = {
    keyword = {
        Match = {
            "早安",
            "早",
            "早上好",
            "晚安",
            "晚安安",
            "晚上好",
            "下午好",
            "中午好",
            "上午好",
            "午安"
        }
    },
    type = "order",
    limit = {
        cd = 180,
    },
    echo = {
        lua = "aibot_good_mn"
    }
}

msg_reply.aibot_switch = {
    keyword = {
        Prefix = {
            ".aibot"
        }
    },
    type = "order",
    echo = {
        lua = "aibot_switch"
    }
}

msg_reply.aibot0 = {
    keyword = {
        Regex = {
            "^[^%.。r](.*)" -- 匹配所有不以指令前缀开头的消息
        }
    },

    type = "order",
    limit = {},
    echo = {
        lua = "aibot"
    }
}

msg_reply.aibot_reply = {
    keyword = {
        Prefix = {
            "[CQ:reply,id=" -- 匹配所有回复消息
        }
    },
    type = "order",
    limit = {},
    echo = {
        lua = "aibot_reply"
    }
}
