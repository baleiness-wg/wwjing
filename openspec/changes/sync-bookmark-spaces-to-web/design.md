# Design

## Context

统一移动端 `flutter_bookmark` 已整合为 `kitchen`（疯狂的厨房，`cookie` 空间，做饭菜谱与随机菜谱）与 `star`（鲸界，`star` 空间，通用网页收藏）双模式。当前 Web 前端 `source/web` 在左侧菜单中仅配置单一的“收藏夹”子菜单项，API 默认全部固定传 `star`，且页面最外层容器使用 `min-height: 100vh`，在 Pad 浏览器上容易产生整页级别的外部滚动条。

## Goals / Non-Goals

**Goals:**
- 将 Web 左侧导航栏与工具总览页中的“收藏夹”升级为目录层级，包含“疯狂的厨房”（访问 `cookie` 空间）与“鲸界”（访问 `star` 空间）两个独立入口。
- 将最外层容器高度限制为 95vh，严格禁止 `html/body/#app/.app-shell` 产生外部整页滚动条，所有滚动仅在内部工作区和侧边栏内自适应产生。
- `BookmarksView` 支持通过路由或 meta 传入 `space` 参数（`cookie` 与 `star`），接口调用全面携带当前 `space`，并在路由变化时刷新数据。
- 为“疯狂的厨房”在 Web 端增加“今天吃什么”随机推荐能力，复用服务端已有的 `/api/bookmarks/random?space=cookie` 接口并在弹窗中展示。

**Non-Goals:**
- 不重写服务端接口：复用服务端已有的 `cookie` 与 `star` 空间支持及 random 接口。
- 不影响现有数据传输（Transfer）与登录页面的独立功能。

## Decisions

### 1. 路由与多空间支持设计

- 路由增加：
  - `/tools/bookmarks/kitchen`：疯狂的厨房，`meta: { space: 'cookie', title: '疯狂的厨房' }`
  - `/tools/bookmarks/star`：鲸界，`meta: { space: 'star', title: '鲸界' }`
  - `/tools/bookmarks`：重定向到 `/tools/bookmarks/star` 保持兼容。
- `BookmarksView` 监听 `route.path` 或 `route.meta.space`，在空间切换时自动重置选中目录并拉取对应空间的数据，避免跨空间数据残留。
- 备选方案：通过 query 参数 `?space=cookie`。弃用原因：目录层级和独立页面入口使用明确的嵌套路由更符合导航目录组织直觉。

### 2. 左侧导航栏层级设计

- `AppLayout.vue` 中在“工具”下支持“收藏夹”二级目录组：
  - 展开“工具”时展示“工具首页”、“数据传输”和“收藏夹”二级目录组。
  - “收藏夹”具备独立的展开/收起状态（访问任一收藏子页面时自动展开），展开后展示“疯狂的厨房”和“鲸界”。
  - 选中态高亮与激活样式保持统一墨绿色。

### 3. 外层 95vh 高度与禁止外部滚动条设计

- 将 `html`, `body`, `#app`, `.app-shell` 的高度锁定为 `height: 95vh; max-height: 95vh; overflow: hidden;`。
- 主内容区域 `.app-main` 设置 `height: calc(95vh - var(--header-height, 60px)); overflow-y: auto; overflow-x: hidden;`。
- 侧边栏 `.app-aside` 设置 `height: 95vh; overflow-y: auto;`。
- 确保在 Pad 浏览器及各分辨率桌面端，视口绝对不会被外部滚动条顶起或发生整体回弹。

### 4. 疯狂的厨房随机菜谱设计

- 在 Web 收藏页顶部工具栏，若当前为 `cookie` 空间，显示“今天吃什么”按钮。
- 点击按钮调用 `/api/bookmarks/random?space=cookie`，弹出居中弹窗展示随机结果，包含封面、菜谱标题、来源信息、原链接直达和“换一个”按钮。

## Risks / Trade-offs

- [空间切换残留状态] → 监听路由 space 变化，清空当前选中目录 `activeFolderId`、搜索关键词 `query` 与已选列表，重新拉取目录树与条目。
- [95vh 导致内部表格或弹窗被截断] → 主工作区容器采用弹性布局，内部列表区设置 `overflow-y: auto`，对话框使用 Element Plus `append-to-body`。
