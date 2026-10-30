# 苔灯镇 · 运行美术素材 01

2026-10-31。按已采用的 B/C 人物像素 v3 制作的**首批运行素材**，覆盖当前可玩灯圃。原概念参考全部保留，未更改既定服饰方向。

## 交付与接入

| 类别 | 文件 / 内容 | 规格与状态 |
| --- | --- | --- |
| 苔林装 | `runtime/keeper_moss.png` | 16帧；默认主角 |
| 星夜装 | `runtime/keeper_star.png` | 16帧；按Esc后在暂停菜单切换，本次游玩生效 |
| 两套角色共同网格 | 每图128×160，4列×4行 | 单帧32×40，脚点(16,36)；行：下、右、左、上；列：待机/步态1/步态2/步态3 |
| 月苔 | `moon_moss_0…3.png` | 16×16，根锚(8,12)，贴地；0/25%/60%/100%四阶段 |
| 灯铃 | `glow_bell_0…3.png` | 16×16，根锚(8,14)，同四阶段 |
| 固定苔灯 | `lantern_broken/off/on.png` | 32×48，基座锚(16,42)，破损/完好熄灭/点亮 |
| UI | `icon_dew/spores/seed_moon/seed_bell.png` | 16×16，分别用于资源与两张种子卡 |
| 林地 | `cottage/tree/stump/mushroom_fern.png` | 128×112 / 112×128 / 40×32 / 32×28，已接入 |
| 孢子袋 | `spore_pouch.png` | 24×24，用于三灯修复完成提示 |

合计 **22张运行PNG，含32个人物帧和20个独立物件/状态**。原始生成图4张在 `source/`；全部为真正透明RGBA。角色身体约26px，星夜帽额外高度计入30px总高。生成帧仍有约1px步态细节变化，后续可做手工逐帧精修。

22张运行PNG均已在游戏代码中接入。外观选择仅改变绘制，保持原有移动、脚底碰撞与交互范围，不消耗资源；选择在本次运行内保留，重新启动恢复场景默认外观。声音试听合辑与备用伴灯草稿不作为普通游玩内容播放。

地表、石路、池塘、栅栏、雾气、交互框和光效继续由程序绘制，与贴图共用原来的640×360逻辑分辨率、整数缩放和最近邻过滤。固定灯的经营光域、作物规则、人物碰撞、存档和苗床布局不由图片决定。本轮未实施12格/M1玩法迁移，也未声称完成未来地区、NPC、战斗或四季资源。

声音见 [音频说明](../audio/README.md)：20个新WAV，其中18个运行声音；备用伴灯音色草稿不在普通游玩中播放。

## 查看

- [素材总览](previews/asset_board.png)
- [实际新灯圃截图](previews/gameplay_moss.png)
- [暂停菜单与外观切换](previews/appearance_menu.png)
- [修灯完成反馈](previews/restoration_complete.png)：无存档检查画面。
- [四阶段与三灯状态检查图](previews/gameplay_states.png)：专用无存档检查场景，不是实际进度截图。
- [音效试听](../audio/v2/audition.wav)

## 来源与复现

美术使用内置 **image_gen**，未使用外部素材库。原图和完整提示词见 [generation-prompts.json](generation-prompts.json)。提示中的请求尺寸/行序不视为已实现数据：实际源图为1254×1254；B输出行序实际是下/右/左/上，切片以检查后的图像为准。物件位置不是严格等分网格，已逐一记录实际裁切区域。

派生图仅做Godot原生裁切、最近邻缩放和透明画布锚点整理；不重新绘画、不抠除颜色背景、不覆盖源文件。制作参数分别在：

- [角色整理脚本](../../tools/prepare_character_art.gd)与[逐帧记录](runtime/character_atlas_manifest.json)
- [物件整理脚本](../../tools/prepare_prop_art.gd)与[物件记录](runtime/prop_manifest.json)

```powershell
# 将 $engine 设为 Godot 4.7.2 标准版可执行文件的实际位置。
& $engine --headless --path . --script res://tools/prepare_character_art.gd
& $engine --headless --path . --script res://tools/prepare_prop_art.gd
& $engine --headless --path . --editor --import
& $engine --headless --path . --script res://tests/smoke_test.gd
& $engine --headless --path . --script res://tests/save_test.gd
# 画面检查需要图形后端；必须使用 fresh-garden，脚本会自动退出。
& $engine --path . --script res://tools/capture_art_preview.gd -- --fresh-garden
python tools/generate_audio.py
```

`source/` 与 `previews/` 带有 `.gdignore`，避免把大原图或检查画面打进游戏。所有运行图均已保留Godot导入配置，不生成mipmap。

## 本轮验证

- Godot 4.7.2标准版导入和OpenGL实机渲染完成；素材总览与640×360画面已目视检查。
- Smoke：种植、成长、资源、修灯、输入、碰撞、暂停、声音成败映射与60/120fps脚步回归通过；暂停换装、选中状态、恢复后保留外观及资源/碰撞不变检查通过。
- Save：真实文件往返、覆盖、静音、备份恢复、损坏存档与错误报告通过。
- 角色32帧足底检查、22张PNG透明度/尺寸检查通过。
- 音频20文件哈希、重复生成一致性、非静音、峰值、首尾与循环边界通过；指标不替代耳机与扬声器听感验收。
- 本机验证使用 `logs/tools-godot/` 的临时标准版；项目原README中的D盘路径在本机不存在。引擎打印一条系统根证书读取错误，测试退出码为0，未发生脚本或资源错误。编辑器用户目录定向 `logs/godot-home/`，未触碰真实玩家存档。
