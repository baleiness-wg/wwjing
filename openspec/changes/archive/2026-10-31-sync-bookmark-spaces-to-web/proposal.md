# Proposal

## Why

统一移动端 `flutter_bookmark` 已经将收藏应用划分为“疯狂的厨房”（`cookie` 空间，聚焦做饭菜谱收藏）和“鲸界”（`star` 空间，通用网页收藏），但在 Web 端的“工具”导航中，收藏夹仍为单一顶层页面且硬编码为 `star` 空间，无法访问厨房菜谱数据。此外，在 Pad 浏览器访问 Web 时容易产生页面级外部滚动条，影响沉浸体验，需要将最外层页面高度锁定为 95vh 并禁止出现外部滚动条。

## What Changes

- 在 Web 端左侧导航栏将“工具”下的“收藏夹”改为可展开收起的二级目录，内部提供“疯狂的厨房”（对应 `cookie` 空间）与“鲸界”（对应 `star` 空间）两个独立入口。
- Web 工具首页（`ToolsView`）同步将收藏夹升级为包含“疯狂的厨房”和“鲸界”的入口集合。
- 扩充路由支持 `/tools/bookmarks/kitchen` 和 `/tools/bookmarks/star`，并保持既有 `/tools/bookmarks` 访问兼容。
- 升级 `BookmarksView` 及 Web 收藏 API 封装，支持根据当前激活空间（`cookie` 或 `star`）动态隔离加载对应目录与收藏，并在 kitchen 模式下支持“今天吃什么”随机菜谱抽取。
- 调整 Web 整体样式与外层布局：最外部高度限定为 95vh，禁止页面主体出现外部滚动条，各功能面板内部支持独立垂直滚动。

## Capabilities

### Modified Capabilities

- `navigation-layout`: 工具导航新增二级“收藏夹”目录项，包含“疯狂的厨房”和“鲸界”两个子项；整体页面最外层高度限制为 95vh 并不允许出现外部滚动条。
- `bookmark-app-modes`: Web 端支持接入 kitchen（`cookie` 空间）与 star（`star` 空间）模式，并在 Web 端实现数据空间隔离和厨房模式特色能力。

## Impact

- Web 页面结构与样式：修改 `source/web/src/layouts/AppLayout.vue`、`source/web/src/views/ToolsView.vue`、`source/web/src/styles/index.css`、`source/web/src/router/index.js`。
- Web 业务组件与接口：修改 `source/web/src/views/BookmarksView.vue`、`source/web/src/api/bookmarks.js`。
- 测试与文档：更新 `source/web/test/bookmarks.api.test.js`、`specs/bookmark-app-modes/spec.md`、`source/web/build.json`。
