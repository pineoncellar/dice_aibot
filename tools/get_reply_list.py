import json

# 读取json文件
with open('CustomMsgReply.json', 'r', encoding='utf-8') as file:
    data = json.load(file)

# 用来存储原始的"match"字段中的值
reply_list = []

# 遍历并修改"match"字段
for key, value in data.items():
    if 'match' in value:
        # 收集原始的"match"字段内容
        reply_list.extend(value['match'])
        
        # 为"match"字段的每个元素加上前缀
        value['match'] = ['reply_' + item for item in value['match']]

# 输出修改后的数据
print(json.dumps(data, ensure_ascii=False, indent=4))

# 保存修改后的数据到新的文件
with open('CustomMsgReply.json', 'w', encoding='utf-8') as file:
    json.dump(data, file, ensure_ascii=False, indent=4)

# 保存原始的"match"字段内容
reply_data = {"reply_list": reply_list}
with open('reply_list.json', 'w', encoding='utf-8') as file:
    json.dump(reply_data, file, ensure_ascii=False, indent=4)
