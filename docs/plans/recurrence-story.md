# v0.3 轮回调查与法杖分支

用户已要求继续实现，并选择“轮回悬疑与反转”。沿用 interface-planning 的接口梳理及 ponytail 的现有能力复用，不增加引擎或收费资源。

## 现状与范围
已核对 rules.gd 的 JSON 状态、offer_staff、stats、validate_run；save_store.gd 的原子替换/备份；workshop.gd 的 commit 回滚；staff_visual.gd 的阶段模型；UI 和 E 交互入口。
本轮实现一条可跨至少三轮推进的调查线、六处环境线索、两种最终选择、三个分支层级和对应模型。原五夜经济循环继续运作。

## 接口与文件职责
- data/chronicle.json：线索、章节条件、正文和七个分支节点定义。
- scripts/chronicle.gd：记忆默认值、验证、线索可用条件、提交匹配、提示；纯数据，无场景依赖。
- rules.gd：new_run(seed, previous) 只继承 campaign；staff.tree 为三个按顺序选择的节点 ID；choose_branch 检查等级和前置。stats(design, level, tree=[]) 统一计算激活分支。offer_staff 同时更新剧情和经济。旧版本缺失字段按默认值迁移，拒绝存在但无效的数据。
- save_store.gd：载入有效旧存档后补默认值。campaign 与 run 在同一个文件中原子保存，不引入第二份事务。
- staff_visual.gd：rebuild(design, level, tree=[])；分支附加几何和灯效共享到手持与灌注模型；降级关闭对应部件但保留选择。
- workshop.gd：J 调查手记、T 升级树、E 线索；统一 commit；新轮回保留记忆，保存失败回滚；场景痕迹刷新。
- ui.gd：分层升级树、已读线索/章节手记、剧情阅读窗、封印提交条件预览。
- gothic_scene.gd：炼金器皿、手稿、星盘等细节；新 environmental_story.gd 放置可调查物与记忆变化，复用现有几何工具。
- tests/test_chronicle.gd：三轮主线、两结局、错误属性/重复提交、旧档、分支边界/降级/序列化。workshop 冒烟补充真实交互、截图和存档。
- tools/build.ps1、文档、版本号：纳入验证并交付 Windows 包/源码。
- spells.gd、balance.json、已有免费资源保持原有职责；施法读取统一 stats 即可获得分支影响。

## 不变量
提交成功才消耗作品；剧情随同一次提交保存，失败整体回滚。新轮回不继承物品，只继承线索、章节、结局与上轮提交回声。同一线索/章节只记一次；后续章节需在指定的后续轮回提交。分支不可改选，等级不足时不生效；未选择分支不阻断原有强化。

## 顺序与验收
1. 数据/规则/存档与可复现脚本验证。
2. 分支外观、场景线索与 UI 集成。
3. 完整原有回归、原生独立包冒烟（含新流程）、实际截图检查、打包 CRC。
剧情时长与难度仅作为演示设计，不宣称已完成真人试玩平衡。
