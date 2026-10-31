# Tasks

## 1. Web 样式与全局高度约束

- [x] 1.1 调整 `source/web/src/styles/index.css`，将最外部容器（html, body, #app, .app-shell）高度严格限制为 95vh，设置 `overflow: hidden` 禁止整页外部滚动条，主内容区与侧边栏内部自适应滚动；通过样式检查和视口高度验证。

## 2. Web API 多空间支持与测试修复

- [x] 2.1 修改 `source/web/src/api/bookmarks.js`，为获取目录、创建目录、更新目录、删除目录、条目查询、条目创建/更新/删除增加对 `space` 参数的显式支持，并增加 `getRandomBookmark(space, folderIds)` 封装；修复并运行 `npm test --prefix source/web` 保证测试全部通过。

## 3. 路由与导航目录层级改造

- [x] 3.1 更新 `source/web/src/router/index.js`，增加 `/tools/bookmarks/kitchen`（空间 `cookie`）和 `/tools/bookmarks/star`（空间 `star`）路由，并将 `/tools/bookmarks` 重定向至 `/tools/bookmarks/star`；验证路由定义与参数传递。
- [x] 3.2 改造 `source/web/src/layouts/AppLayout.vue`，在工具菜单中将“收藏夹”实现为二级目录折叠组，包含“疯狂的厨房”和“鲸界”两个子项，并在访问对应页面时保持正确高亮与展开；更新 `source/web/src/views/ToolsView.vue` 工具卡片，体现“疯狂的厨房”和“鲸界”双入口。

## 4. Web 收藏页多空间与厨房随机推荐功能

- [x] 4.1 改造 `source/web/src/views/BookmarksView.vue`，动态响应路由中的空间切换，隔离请求对应 `cookie` 或 `star` 空间的目录与收藏列表，并根据空间调整页面标题与引导文案。
- [x] 4.2 在 `BookmarksView.vue` 中为“疯狂的厨房”（`cookie` 空间）添加“今天吃什么”随机抽取按钮与弹窗卡片，支持原链接跳转与再次随机；在“鲸界”模式下隐藏该按钮。

## 5. 构建验证与版本信息更新

- [x] 5.1 运行 `npm run build --prefix source/web` 与 `npm test --prefix source/web` 验证前端构建与测试通过。
- [x] 5.2 更新 `specs/bookmark-app-modes/spec.md` 及 `source/web/build.json` 版本与模型信息，按项目规则备份旧文件。

## Workflow follow-up

- 完成后归档该 OpenSpec 变更。
