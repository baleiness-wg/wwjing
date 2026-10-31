# Proposal

## Why

统一收藏客户端虽然已启用 Material 3，但“收藏链接”悬浮入口和目录选择项仍手工组合外观与选中状态，增加了样式、语义和交互状态的维护成本。优先采用 Flutter 官方 Material 组件，可以获得一致的按压、焦点、无障碍和主题行为，同时减少重复 UI 代码。

## What Changes

- 将手工拼装的“收藏链接”控件替换为官方 `FloatingActionButton.extended`，保留当前可拖动位置与点击打开收藏表单的行为。
- 将目录选择弹窗中手工绘制的选中背景和勾选状态替换为官方单选组件，保留目录层级缩进、“未分类”和在选中目录下新建目录的能力。
- 将收藏表单中的目录入口替换为官方 Material 选择入口组合，不再手工模拟输入框点击效果。
- 统一收藏条目、子目录和目录选择区域使用官方 Material Card 变体及主题，不自行绘制重复的卡片视觉效果。
- 保留封面加载失败后的来源域名占位、目录树层级、拖放校验、随机结果精简卡片、平台跳转和业务弹窗等领域逻辑。
- 不引入第三方 UI 库，不改变 kitchen/star 模式、服务端接口或收藏数据。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `bookmark-app-modes`: 统一客户端的页面交互新增官方 Material 3 组件优先、标准状态反馈及业务行为保持要求。

## Impact

- 主要修改 `source/flutter_bookmark/lib/widgets/home_page.dart`、`bookmark_form.dart`、`bookmark_item_card.dart` 和全局主题配置。
- 更新 Flutter Widget 测试，覆盖官方 FAB 的点击/拖动区分、目录单选、“未分类”映射和随机卡片精简状态。
- 更新 `specs/bookmark-app-modes/spec.md` 历史版本及 `source/flutter_bookmark/build.json`。
- 不修改 Node API、数据库、Android flavor、MethodChannel 或第三方依赖。
