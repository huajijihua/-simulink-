from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

out = Path(r"E:\agentwork_pemfc_cEGR_0519\01_自吸方案\02_台架测试_10kW\05_汇报\life_formula_slide_clean.png")
out.parent.mkdir(parents=True, exist_ok=True)

W, H = 1920, 1080
img = Image.new("RGB", (W, H), "white")
d = ImageDraw.Draw(img)

ft_title = ImageFont.truetype(r"C:\Windows\Fonts\simhei.ttf", 44)
ft_sub = ImageFont.truetype(r"C:\Windows\Fonts\msyhbd.ttc", 26)
ft_formula = ImageFont.truetype(r"C:\Windows\Fonts\NotoSansSC-VF.ttf", 32)
ft_small = ImageFont.truetype(r"C:\Windows\Fonts\NotoSansSC-VF.ttf", 22)
ft_small2 = ImageFont.truetype(r"C:\Windows\Fonts\NotoSansSC-VF.ttf", 18)
ft_note = ImageFont.truetype(r"C:\Windows\Fonts\NotoSansSC-VF.ttf", 17)

ink = (28, 28, 28)
gray = (96, 96, 96)
blue = (39, 103, 173)
light = (233, 239, 247)
line = (210, 218, 228)


def center_text(y, text, font, fill=ink):
    bbox = d.textbbox((0, 0), text, font=font)
    w = bbox[2] - bbox[0]
    d.text(((W - w) / 2, y), text, font=font, fill=fill)


def rounded_box(xy, radius=24, fill=(248, 248, 248), outline=line, width=2):
    d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


for y in range(0, H, 120):
    d.line((0, y, W, y), fill=(248, 249, 251), width=1)

center_text(34, "PEMFC 寿命计算模块公式", ft_title)
center_text(92, "简化版：输入因子 -> 等效衰减率 -> 累计衰减 / 预计寿命 / ECSA 代理量", ft_small, fill=gray)

rounded_box((120, 140, 1800, 348), radius=28, fill=(250, 252, 255), outline=(205, 218, 234), width=2)
d.text((160, 168), "核心输出", font=ft_sub, fill=blue)
main_formula = "life_damage_rate_mV_h = base_decay_mV_h × f_V × f_RH × f_T × f_j × f_cycle"
bbox = d.multiline_textbbox((0, 0), main_formula, font=ft_formula, spacing=8)
d.multiline_text(((W - (bbox[2] - bbox[0])) / 2, 204), main_formula, font=ft_formula, fill=ink, spacing=8, align="center")
d.line((220, 280, 1700, 280), fill=(220, 228, 238), width=2)
center_text(298, "delta_V_deg_mV = life_damage_rate_mV_h × duration_h    |    projected_life_to_EOL_h = allowable_decay_mV / life_damage_rate_mV_h", ft_small, fill=gray)
center_text(332, "ECSA_ratio_proxy = 1 - (1 - ECSA_EOL_ratio) × sat01(damage_index)", ft_small, fill=gray)

center_text(384, "四个主因子 + 一个循环项", ft_sub, fill=blue)

box_y1, box_y2 = 420, 762
box_w, gap, x0 = 380, 35, 120

boxes = [
    (
        "f_V  电位因子",
        [
            "f_base_V = exp(k_potential_exp × (V_cell - V_ref))",
            "over_high = max((V_cell - V_high) / V_scale_high, 0)",
            "under_low = max((V_low - V_cell) / V_scale_low, 0)",
            "f_V = sat(f_base_V × (1 + k_over_high × over_high^2)",
            "         + k_low_voltage × under_low^2)",
        ],
        "重点惩罚高电位 > 0.8 V",
    ),
    (
        "f_RH  湿度因子",
        [
            "dryness = max((RH_min - RH_ca_in) / RH_min, 0)",
            "f_RH = sat(1 + k_dry × dryness^2)",
        ],
        "只对干燥风险加罚",
    ),
    (
        "f_T  温度因子",
        [
            "T_K = T_stack_C + 273.15",
            "f_T = exp(Ea / R × (1 / T_ref - 1 / T_K))",
        ],
        "Arrhenius 等效加速",
    ),
    (
        "f_j / f_cycle",
        [
            "low_current = max((j_low - j) / j_low, 0)",
            "high_current = max((j - j_high) / j_high, 0)",
            "f_j = sat(1 + k_j_low × low_current^2 + k_j_high × high_current^2)",
            "f_cycle = sat(1 + k_djdt × |dj/dt| / djdt_ref)",
        ],
        "稳态扫描中 f_cycle = 1",
    ),
]

for i, (title, lines, note) in enumerate(boxes):
    x1 = x0 + i * (box_w + gap)
    x2 = x1 + box_w
    rounded_box((x1, box_y1, x2, box_y2), radius=22, fill=(255, 255, 255), outline=(214, 220, 228), width=2)
    d.rectangle((x1, box_y1, x2, box_y1 + 54), fill=light)
    d.text((x1 + 18, box_y1 + 13), title, font=ft_sub, fill=blue)

    y = box_y1 + 78
    for line_txt in lines:
        d.text((x1 + 18, y), line_txt, font=ft_small2, fill=ink)
        y += 34

    d.text((x1 + 18, box_y2 - 36), note, font=ft_note, fill=gray)

rounded_box((120, 800, 1800, 960), radius=20, fill=(252, 252, 252), outline=(224, 224, 224), width=2)
d.text((160, 826), "参数口径", font=ft_sub, fill=blue)
center_text(870, "base_decay_mV_h = 0.012 mV/h    |    allowable_decay_mV = 75 mV    |    ECSA_EOL_ratio = 0.60", ft_small, fill=ink)
center_text(915, "说明：该模型用于相对寿命排序与趋势比较，未做长期耐久绝对标定。", ft_small, fill=gray)

footer = "适合直接插入 PPT：一页讲清公式结构"
bbox = d.textbbox((0, 0), footer, font=ft_note)
d.text((W - (bbox[2] - bbox[0]) - 42, 978), footer, font=ft_note, fill=(130, 130, 130))

img.save(out)
print(out)
