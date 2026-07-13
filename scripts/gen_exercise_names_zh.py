#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""离线生成动作中文名。

数据集动作名高度公式化（[器械][姿势][部位][动作]），用"短语优先 + 词元兜底"的
贪心最长匹配把英文名翻成中文。无需联网 / LLM，结果落地为 externalId -> 中文名 的 JSON，
随包分发，App 端运行时按 externalId 查表（不改 SwiftData 模型，零迁移风险）。

用法: python3 scripts/gen_exercise_names_zh.py
输出: FitGenius/Resources/ExerciseLibrary/exercise_names_zh.json
"""
import json, re, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED = os.path.join(ROOT, "FitGenius/Resources/ExerciseLibrary/exercises_seed.json")
OUT = os.path.join(ROOT, "FitGenius/Resources/ExerciseLibrary/exercise_names_zh.json")

# 多词短语（优先匹配，长的在前）。key 为空格分隔的小写词序列。
PHRASES = {
    "good morning": "早安式体前屈",
    "sit up": "仰卧起坐", "sit ups": "仰卧起坐", "situp": "仰卧起坐",
    "push up": "俯卧撑", "push ups": "俯卧撑", "pushup": "俯卧撑",
    "pull up": "引体向上", "pull ups": "引体向上", "pullup": "引体向上",
    "chin up": "反握引体向上", "chin ups": "反握引体向上",
    "close grip": "窄握", "wide grip": "宽握", "narrow grip": "窄握",
    "neutral grip": "对握", "reverse grip": "反握", "underhand grip": "反握",
    "overhand grip": "正握", "mixed grip": "正反握", "pronated grip": "正握",
    "supinated grip": "反握", "pronate grip": "正握",
    "one arm": "单臂", "single arm": "单臂", "two arm": "双臂", "both arms": "双臂",
    "one leg": "单腿", "single leg": "单腿", "two leg": "双腿", "single legged": "单腿",
    "bent over": "俯身", "bent knee": "屈膝", "bent legs": "屈膝",
    "cross body": "对侧", "behind head": "颈后", "behind neck": "颈后",
    "behind the neck": "颈后", "over the": "", "on the": "",
    "lateral raise": "侧平举", "front raise": "前平举", "rear raise": "后平举",
    "calf raise": "提踵", "leg raise": "举腿", "leg raises": "举腿",
    "leg press": "腿举", "leg extension": "腿屈伸", "leg curl": "腿弯举",
    "upright row": "直立划船", "bench press": "卧推", "shoulder press": "肩上推举",
    "chest press": "胸推", "military press": "站姿推举", "overhead press": "过头推举",
    "hip thrust": "臀冲", "hip thrusts": "臀冲", "glute bridge": "臀桥",
    "hip bridge": "臀桥", "skull crusher": "碎颅式臂屈伸", "skull crushers": "碎颅式臂屈伸",
    "triceps extension": "三头肌臂屈伸", "tricep extension": "三头肌臂屈伸",
    "biceps curl": "二头肌弯举", "bicep curl": "二头肌弯举",
    "hammer curl": "锤式弯举", "preacher curl": "牧师凳弯举",
    "concentration curl": "集中弯举", "spider curl": "蜘蛛弯举",
    "wrist curl": "腕弯举", "reverse curl": "反握弯举",
    "lat pulldown": "高位下拉", "lateral pulldown": "高位下拉",
    "front lever": "前水平", "back lever": "后水平",
    "russian twist": "俄式转体", "mountain climber": "登山者",
    "jumping jack": "开合跳", "jumping jacks": "开合跳",
    "dead bug": "死虫式", "bird dog": "鸟狗式", "downward dog": "下犬式",
    "cossack squat": "哥萨克深蹲", "goblet squat": "高脚杯深蹲",
    "hack squat": "哈克深蹲", "sissy squat": "西西里深蹲", "pistol squat": "手枪蹲",
    "sumo deadlift": "相扑硬拉", "romanian deadlift": "罗马尼亚硬拉",
    "stiff leg deadlift": "直腿硬拉", "stiff legged deadlift": "直腿硬拉",
    "farmers walk": "农夫行走", "turkish get up": "土耳其起立",
    "clean and jerk": "挺举", "power clean": "高翻",
    "face pull": "面拉", "high pull": "高翻拉", "band pull apart": "弹力带扩胸",
    "toe touch": "触趾", "flutter kick": "交替踢腿", "scissor kick": "剪刀腿",
    "wall sit": "靠墙静蹲", "box jump": "跳箱", "jump squat": "跳深蹲",
    "split squat": "分腿蹲", "bulgarian split squat": "保加利亚分腿蹲",
    "step up": "登踏", "step ups": "登踏", "battle rope": "战绳",
    "battling rope": "战绳", "battling ropes": "战绳", "medicine ball": "药球",
    "exercise ball": "健身球", "stability ball": "健身球", "swiss ball": "瑞士球",
    "bosu ball": "波速球", "foam roller": "泡沫轴", "ab wheel": "健腹轮",
    "resistance band": "弹力带", "smith machine": "史密斯机",
    "v bar": "V型杆", "v raise": "V字上举", "y raise": "Y字上举",
    "rear delt": "后束三角肌", "front delt": "前束三角肌", "side delt": "侧束三角肌",
    "reverse fly": "反向飞鸟", "reverse flye": "反向飞鸟", "chest fly": "胸部飞鸟",
    "incline bench": "上斜卧", "decline bench": "下斜卧", "flat bench": "平板卧",
    "good mornings": "早安式体前屈",
    "ez bar": "EZ杠", "ez barbell": "EZ杠", "straight bar": "直杠",
    "sz bar": "SZ杠", "cambered bar": "曲杠", "trap bar": "六角杠",
    "pelvic tilt": "骨盆倾斜", "stork stance": "金鸡独立",
    "world greatest": "世界最佳", "range of motion": "全程",
    "get up": "起立", "bird dog": "鸟狗式", "dead bug": "死虫式",
    "butterfly yoga pose": "蝴蝶式瑜伽", "yoga pose": "瑜伽体式",
    "skin the cat": "翻筋斗", "figure 8": "8字", "figure four": "4字",
    "jack knife": "折刀", "hip internal rotation": "髋内旋",
    "hip external rotation": "髋外旋", "internal rotation": "内旋",
    "external rotation": "外旋", "back and forth": "前后",
    "arm blaster": "臂力轰炸器", "arm slingers": "摆臂",
    "toe touchers": "触趾", "heel touchers": "触跟",
    "upward facing dog": "上犬式", "downward facing dog": "下犬式",
    "body saw": "身体拉锯", "scapular pull": "肩胛引体",
    "russian twist": "俄式转体",
}

# 单词元兜底
TOKENS = {
    # 器械
    "dumbbell": "哑铃", "dumbbells": "哑铃", "barbell": "杠铃", "cable": "绳索",
    "kettlebell": "壶铃", "smith": "史密斯", "band": "弹力带", "lever": "器械",
    "machine": "器械", "sled": "雪橇", "ez": "EZ杠", "bar": "杠铃杆",
    "bosu": "波速球", "ball": "球", "roller": "泡沫轴", "wheel": "健腹轮",
    "rope": "绳", "cambered": "曲杆", "landmine": "杠铃底座", "pulley": "滑轮",
    "trap": "六角杠", "handle": "把手", "attachment": "配件", "strap": "带",
    "straps": "带", "towel": "毛巾", "chair": "椅", "wall": "墙", "bench": "卧凳",
    "benches": "卧凳", "box": "箱", "platform": "踏板", "stepbox": "踏板",
    "bike": "单车", "treadmill": "跑步机", "elliptical": "椭圆机", "ergometer": "测功仪",
    "stepmill": "登山机", "stepper": "踏步机", "trainer": "训练器", "tire": "轮胎",
    "sledge": "大锤", "sledgehammer": "大锤", "suspended": "悬吊", "suspension": "悬吊",
    "ring": "吊环", "rings": "吊环", "parallel": "双杠", "bars": "双杠", "gripper": "握力器",
    # 姿势/修饰
    "seated": "坐姿", "sitted": "坐姿", "standing": "站姿", "lying": "仰卧",
    "incline": "上斜", "decline": "下斜", "flat": "平", "prone": "俯卧",
    "supine": "仰卧", "reclining": "仰卧", "kneeling": "跪姿", "kneel": "跪姿",
    "bent": "俯身", "reverse": "反向", "revers": "反向", "close": "窄",
    "closer": "窄", "wide": "宽", "narrow": "窄", "single": "单", "one": "单",
    "two": "双", "double": "双", "alternate": "交替", "alternating": "交替",
    "overhead": "过头", "front": "前", "rear": "后", "side": "侧", "lateral": "侧",
    "cross": "交叉", "hammer": "锤式", "preacher": "牧师凳", "concentration": "集中",
    "spider": "蜘蛛", "zottman": "佐特曼", "arnold": "阿诺德", "military": "站姿",
    "french": "法式", "high": "高位", "low": "低位", "middle": "中位", "mid": "中位",
    "wide": "宽", "straight": "直", "half": "半", "full": "全", "quarter": "四分之一",
    "weighted": "负重", "assisted": "辅助", "bodyweight": "自重", "isometric": "等长",
    "static": "静态", "dynamic": "动态", "explosive": "爆发", "plyo": "增强式",
    "plyometric": "增强式", "eccentric": "离心", "negative": "离心", "hold": "保持",
    "twisting": "转体", "twisted": "转体", "rotational": "旋转", "rotation": "旋转",
    "diagonal": "斜向", "vertical": "垂直", "horizontal": "水平", "inverted": "倒立",
    "inverse": "反向", "elevated": "垫高", "raised": "抬高", "supported": "支撑",
    "self": "自身", "wide": "宽", "neutral": "对握", "pronated": "正握", "supinated": "反握",
    "underhand": "反握", "overhand": "正握", "pronate": "正握", "supinate": "反握",
    "gripless": "无握", "grip": "握", "palms": "掌心", "palm": "掌心",
    "wide": "宽", "sumo": "相扑", "romanian": "罗马尼亚", "stiff": "直",
    "cossack": "哥萨克", "goblet": "高脚杯", "hack": "哈克", "sissy": "西西里",
    "pistol": "手枪式", "bulgarian": "保加利亚", "zercher": "泽奇", "jefferson": "杰斐逊",
    "svend": "斯文德", "cuban": "古巴", "bradford": "布拉德福德", "pallof": "帕洛夫",
    "spell": "拼写", "caster": "举重", "windmill": "风车", "renegade": "反叛者",
    "turkish": "土耳其", "farmers": "农夫", "waiter": "侍者", "gorilla": "大猩猩",
    "frog": "青蛙", "frankenstein": "科学怪人", "superman": "超人", "cobra": "眼镜蛇",
    "sphinx": "斯芬克斯", "handstand": "倒立", "planche": "俯卧撑腾身", "maltese": "马耳他",
    "l": "L型", "star": "星式", "flag": "旗式", "archer": "弓箭手", "clap": "击掌",
    "diamond": "钻石", "pike": "屈体", "tuck": "团身", "straddle": "分腿", "stalder": "斯塔尔德",
    "muscle": "双力臂", "kipping": "卷身", "burpee": "波比", "inchworm": "毛毛虫",
    "crawl": "爬行", "bear": "熊爬", "crab": "螃蟹", "skater": "滑冰者", "skate": "滑冰",
    "skier": "滑雪者", "ski": "滑雪", "sprint": "冲刺", "sprints": "冲刺", "run": "跑",
    "runners": "跑者", "running": "跑", "walk": "行走", "walking": "行走", "march": "踏步",
    "jump": "跳", "jumps": "跳", "jumping": "跳", "hops": "跳", "hop": "跳",
    "jack": "开合", "thruster": "推举深蹲", "wall": "墙", "cocoons": "屈膝收腹",
    # 动作
    "curl": "弯举", "curls": "弯举", "press": "推举", "presses": "推举",
    "row": "划船", "raise": "上举", "raises": "上举", "extension": "伸展",
    "fly": "飞鸟", "flye": "飞鸟", "flyes": "飞鸟", "flye": "飞鸟",
    "pulldown": "下拉", "pullover": "上拉", "squat": "深蹲", "squats": "深蹲",
    "squatting": "深蹲", "deadlift": "硬拉", "lunge": "弓步", "lunges": "弓步",
    "dip": "臂屈伸", "dips": "臂屈伸", "crunch": "卷腹", "crunches": "卷腹",
    "pushdown": "下压", "kickback": "后踢臂屈伸", "kickbacks": "后踢臂屈伸",
    "twist": "转体", "twists": "转体", "shrug": "耸肩", "shrugs": "耸肩",
    "bridge": "臀桥", "thrust": "顶髋", "thrusts": "顶髋", "plank": "平板支撑",
    "clean": "翻站", "snatch": "抓举", "jerk": "挺举", "swing": "摆荡", "swings": "摆荡",
    "pull": "拉", "push": "推", "pullup": "引体向上", "chinup": "反握引体向上",
    "kick": "踢", "kicks": "踢", "throw": "抛", "slam": "砸", "carry": "搬运",
    "drag": "拖拉", "flip": "翻转", "hyperextension": "背屈伸", "hyper": "背屈伸",
    "extension": "伸展", "flexion": "屈曲", "adduction": "内收", "abduction": "外展",
    "pronation": "旋前", "supination": "旋后", "circles": "绕环", "circular": "绕环",
    "circle": "绕环", "reach": "伸展", "touch": "触碰", "tap": "点触", "bend": "弯曲",
    "bends": "弯曲", "lift": "上提", "lifts": "上提", "drive": "驱动", "drop": "下放",
    "roll": "滚动", "rollout": "滚动", "rollerout": "滚动", "rolling": "滚动",
    "windmill": "风车", "wiper": "雨刷", "wipers": "雨刷", "get": "起立", "up": "起",
    "sit": "仰卧起坐", "chin": "引体向上", "jackknife": "折刀", "seesaw": "跷跷板",
    "climb": "攀爬", "climber": "登山", "step": "登踏", "walkout": "走步俯撑",
    # 部位 / 肌群
    "chest": "胸部", "pec": "胸肌", "pectoralis": "胸大肌", "back": "背部", "lat": "背阔肌",
    "lats": "背阔肌", "shoulder": "肩部", "shoulders": "肩部", "delt": "三角肌",
    "delts": "三角肌", "deltoid": "三角肌", "arm": "手臂", "arms": "手臂",
    "biceps": "二头肌", "bicep": "二头肌", "triceps": "三头肌", "tricep": "三头肌",
    "forearm": "前臂", "forearms": "前臂", "wrist": "手腕", "wrists": "手腕",
    "finger": "手指", "hand": "手", "hands": "手", "leg": "腿部", "legs": "腿部",
    "legged": "腿", "calf": "小腿", "calves": "小腿", "quad": "股四头肌", "quads": "股四头肌",
    "hamstring": "腘绳肌", "hamstrings": "腘绳肌", "glute": "臀部", "glutes": "臀部",
    "gluteus": "臀大肌", "hip": "髋部", "hips": "髋部", "core": "核心", "ab": "腹肌",
    "abs": "腹肌", "abdominal": "腹部", "oblique": "腹斜肌", "obliques": "腹斜肌",
    "neck": "颈部", "spine": "脊柱", "knee": "膝", "knees": "膝", "ankle": "踝",
    "ankles": "踝", "toe": "脚趾", "toes": "脚趾", "heel": "脚跟", "feet": "双脚",
    "foot": "脚", "elbow": "肘", "trap": "斜方肌", "traps": "斜方肌", "hamstring": "腘绳肌",
    "adductor": "内收肌", "abductor": "外展肌", "inner": "内侧", "outer": "外侧",
    "upper": "上部", "lower": "下部", "middle": "中部", "rectus": "直肌", "femoris": "股",
    "flexor": "屈肌", "flexors": "屈肌", "piriformis": "梨状肌", "tibialis": "胫骨前肌",
    "peroneals": "腓骨肌", "groin": "腹股沟", "hamstring": "腘绳肌",
    # 其它
    "with": "配", "and": "加", "to": "至", "the": "", "a": "", "of": "", "on": "",
    "in": "", "for": "", "from": "", "into": "", "against": "对抗", "between": "间",
    "behind": "身后", "over": "过顶", "under": "下方", "across": "横向", "around": "环绕",
    "through": "穿过", "off": "离", "out": "外", "down": "向下", "forward": "向前",
    "backward": "向后", "upward": "向上", "left": "左", "right": "右", "outer": "外侧",
    "exercise": "训练", "workout": "训练", "variation": "变式", "advanced": "进阶",
    "intermediate": "中级", "basic": "基础", "modified": "改良", "wide": "宽",
    "v": "V型", "y": "Y型", "t": "T型", "w": "W型", "cross": "交叉",
    "male": "", "female": "", "pov": "", "version": "版本",
    # 补充：拉伸/悬垂/器械/杂项
    "stretch": "拉伸", "stretches": "拉伸", "stretching": "拉伸",
    "floor": "地面", "hanging": "悬垂", "hang": "悬垂", "hangs": "悬垂",
    "support": "支撑", "supported": "支撑", "donkey": "驴式",
    "scapula": "肩胛", "scapular": "肩胛", "fixed": "固定",
    "internal": "内", "external": "外", "head": "头后", "body": "身体",
    "rocky": "洛基", "rocking": "摇摆", "bottoms": "底端", "bottom": "底端",
    "crossover": "交叉", "crossovers": "交叉", "cage": "深蹲架", "iron": "铁",
    "face": "面", "tennis": "网球", "squeeze": "收缩", "pass": "传递",
    "olympic": "奥林匹克", "posterior": "后侧", "anterior": "前侧",
    "potty": "如厕式", "stationary": "固定", "three": "三", "air": "空中",
    "apart": "分开", "motion": "运动", "major": "大肌", "astride": "跨立",
    "forth": "向前", "balance": "平衡", "board": "板", "bicycle": "自行车",
    "knife": "刀式", "both": "双", "skull": "碎颅式", "guillotine": "断头台式",
    "lifting": "上提", "stance": "站姿", "pendlay": "潘德利", "pin": "限位",
    "rack": "架", "speed": "快速", "stabilization": "稳定", "buttups": "翘臀",
    "butt": "臀", "butterfly": "蝴蝶式", "judo": "柔道", "pro": "专业",
    "stirrups": "脚蹬", "sz": "SZ杠", "russian": "俄式",
    "kayak": "皮划艇", "captains": "船长椅", "captain": "船长椅",
    "clock": "时钟", "curtsey": "屈膝礼", "curtsy": "屈膝礼", "cycle": "循环",
    "deep": "深", "bowling": "保龄球", "contralateral": "对侧", "can": "罐头式",
    "breeding": "繁殖式", "femoral": "股", "peacher": "牧师凳", "scott": "斯科特",
    "rotate": "旋转", "rotary": "旋转", "world": "世界", "above": "上方",
    "tate": "泰特", "elevator": "升降", "ground": "地面", "hug": "环抱",
    "pyramid": "金字塔", "antigravity": "抗重力", "gravity": "重力",
    "flutter": "摆动", "reps": "次", "gironda": "吉隆达", "sternum": "胸骨",
    "ham": "腘绳肌", "clasped": "交扣", "reversed": "反向", "keens": "膝",
    "hyght": "海特", "impossible": "极限", "depth": "深度", "janda": "扬达",
    "position": "姿势", "figure": "字形", "pirate": "海盗", "supper": "晚餐",
    "style": "式", "korean": "韩式", "lean": "前倾", "hook": "钩拳",
    "boxing": "拳击", "pad": "垫", "unilateral": "单侧", "london": "伦敦",
    "catch": "接", "multiple": "多次", "response": "反应", "release": "释放",
    "hindu": "印度式", "monster": "怪兽", "otis": "奥蒂斯", "outside": "外侧",
    "inside": "内侧", "prisoner": "囚徒", "plus": "加强", "quick": "快速",
    "big": "大", "pose": "体式", "equipment": "器械", "scissor": "剪刀",
    "sequence": "序列", "angle": "角度", "semi": "半", "short": "短",
    "stride": "步幅", "outstretched": "伸展", "slide": "滑动", "cat": "猫式",
    "skin": "穿越", "degrees": "度", "angled": "斜角", "split": "分腿",
    "range": "幅度", "staircase": "楼梯", "fallout": "前伸", "swimmer": "游泳者",
    "twin": "双", "facing": "朝向", "dog": "犬式", "round": "圆背",
    "wind": "转体", "greatest": "最佳", "depresor": "下压", "retractor": "回收",
    "jm": "JM", "blaster": "轰炸器", "slingers": "摆臂", "touchers": "触碰",
    "quads": "股四头肌", "glutes": "臀部", "calves": "小腿", "keens": "膝",
    "point": "点", "tilt": "倾斜", "pelvic": "骨盆", "thibaudeau": "蒂博多",
    "extended": "伸展", "squad": "深蹲", "fours": "四肢", "all": "全",
    "skullcrusher": "碎颅式臂屈伸", "ups": "起", "upright": "直立",
    "anti": "抗", "power": "爆发", "rollerer": "滚动", "rack": "架",
}

# 括号内直接丢弃的标记
DROP_PAREN = {"male", "female", "pov", "side pov", "back pov", "front pov"}

def normalize(name: str):
    s = name.lower().strip()
    # 处理版本 "v. 2" / "v.2" -> " 版本2"
    s = re.sub(r"\bv\.?\s*(\d+)", r" 版本\1 ", s)
    # 去掉可丢弃的括号内容
    def _paren(m):
        inner = m.group(1).strip()
        if inner in DROP_PAREN:
            return " "
        return " " + inner + " "
    s = re.sub(r"\(([^)]*)\)", _paren, s)
    # 修复数据集里 45в° 之类的乱码
    s = s.replace("в°", "度").replace("°", "度")
    # 统一分隔符（保留数字间的分数斜杠，如 3/4）
    s = re.sub(r"(?<!\d)/|/(?!\d)", " ", s)  # 只把非分数的"/"当分隔符
    s = re.sub(r"[\-_.,]", " ", s)
    s = re.sub(r"[^a-z0-9 /]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def translate(name: str):
    s = normalize(name)
    words = [w for w in s.split(" ") if w]
    out = []
    untranslated = 0
    i = 0
    n = len(words)
    while i < n:
        matched = False
        # 短语最长匹配（4->1）
        for span in range(min(4, n - i), 1, -1):
            phrase = " ".join(words[i:i+span])
            if phrase in PHRASES:
                val = PHRASES[phrase]
                if val:
                    out.append(val)
                i += span
                matched = True
                break
        if matched:
            continue
        w = words[i]
        if w in TOKENS:
            val = TOKENS[w]
            if val:
                out.append(val)
        elif re.fullmatch(r"\d+", w):
            out.append(w)
        else:
            out.append(w)  # 保留英文原词
            untranslated += 1
        i += 1
    zh = "".join(out).strip()
    if not zh:
        zh = name
    return zh, untranslated

def main():
    data = json.load(open(SEED, encoding="utf-8"))
    result = {}
    fully = 0
    partial_samples = []
    for r in data:
        zh, un = translate(r["name"])
        result[r["id"]] = zh
        if un == 0:
            fully += 1
        elif len(partial_samples) < 30:
            partial_samples.append((r["name"], zh))
    json.dump(result, open(OUT, "w", encoding="utf-8"),
              ensure_ascii=False, separators=(",", ":"))
    total = len(data)
    print(f"生成 {total} 条 -> {OUT}")
    print(f"完全中文化: {fully} ({fully*100//total}%)  含残留英文: {total-fully}")
    print("--- 残留英文样例 ---")
    for en, zh in partial_samples:
        print(f"{en}  =>  {zh}")

if __name__ == "__main__":
    main()
