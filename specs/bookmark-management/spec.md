# bookmark-management 模块规格说明

- 版本：202610260111
- 最后更新：2026-10-26
- 模块名称：bookmark-management（跨端私人收藏夹）

---

## 业务概述

bookmark-management 模块为同一账号提供跨 Android 与 Web 的私人链接收藏和嵌套目录管理能力。Android Flutter 客户端负责从其他应用的系统分享或用户剪贴板快速接收链接，Web 客户端作为后台管理入口负责集中搜索和整理；二者复用 Node 登录服务、收藏接口和 PostgreSQL 数据。

### 核心业务流程

- 用户通过现有用户名和密码登录 Android 或 Web 客户端，收藏接口依据 Bearer JWT 中的用户身份隔离数据。
- Android 用户可从其他应用分享文本到收藏应用；应用提取第一个 HTTP/HTTPS 链接，并预填标题、描述和目录选择表单。
- 用户主动打开 Android 应用时，如果剪贴板中存在尚未处理的链接，应用显示非阻塞收藏提示，不自动上传或保存剪贴板内容。
- 用户可不填写标题和描述，直接将链接保存为未分类或保存到一个已有收藏夹；目录选择器优先展示最近使用目录。
- 用户可创建最多 8 层的嵌套收藏夹，并对目录进行重命名、移动和排序；系统禁止循环移动，非空目录不得删除。
- 系统保存原始链接、规范化链接和来源主机；检测到同一用户已有相同规范化链接时提示原收藏位置，用户仍可明确选择重复保存。
- Web 用户从“工具 / 收藏夹”进入管理页面，可按目录或未分类状态浏览，通过标题、描述或链接搜索，并创建、编辑、移动、批量移动或删除收藏。
- Android 与 Web 修改同一服务端数据，任一客户端刷新后均显示最新目录和收藏内容。

### 页面布局约束

- Android 手机布局使用侧边抽屉显示全部收藏、未分类和目录树；宽屏 Android 设备使用常驻左侧目录栏。
- Android 快速收藏表单在一个页面显示链接、标题、描述和目录，链接有效时保存按钮立即可用。
- Android 收到分享时若登录已过期，必须保留待收藏草稿，重新登录成功后恢复表单。
- Web 收藏夹页采用左侧目录树、右侧搜索和收藏列表的布局；窄屏时改为纵向排列且不得产生页面级横向滚动。
- 每个目录均提供新增子目录和添加收藏入口；目录移动候选项不得包含自身及其后代。
- 收藏保存或更新失败时，客户端必须保留用户已输入的链接、标题和描述。

## 接口说明

所有收藏接口以 `/api/bookmarks` 开头，要求携带有效的 `Authorization: Bearer <token>` 请求头，并依据认证上下文确定当前用户。客户端不得提交 `userId` 作为授权依据。

### 获取收藏夹列表

- **接口路径**：`/api/bookmarks/folders`
- **请求方式**：GET
- **请求参数**：无
- **返回参数**：当前用户收藏夹的扁平数组，包含目录标识、父目录标识、名称、排序位置和更新时间。

```json
{
  "folders": [
    {
      "id": "1",
      "parentId": null,
      "name": "稍后观看",
      "position": 0,
      "createdAt": "2026-10-26T01:11:00.000Z",
      "updatedAt": "2026-10-26T01:11:00.000Z"
    }
  ]
}
```

### 创建收藏夹

- **接口路径**：`/api/bookmarks/folders`
- **请求方式**：POST
- **请求参数**：`name` 为 1 至 120 个字符；`parentId` 可为空；`position` 为非负整数。
- **返回参数**：创建后的收藏夹对象。

```json
{
  "name": "技术",
  "parentId": "1",
  "position": 0
}
```

### 更新收藏夹

- **接口路径**：`/api/bookmarks/folders/:id`
- **请求方式**：PATCH
- **请求参数**：可提交 `name`、`parentId` 或 `position`；移动后目录深度不得超过 8 层且不得形成循环。
- **返回参数**：更新后的收藏夹对象。

```json
{
  "name": "开发资料",
  "parentId": null,
  "position": 1
}
```

### 删除收藏夹

- **接口路径**：`/api/bookmarks/folders/:id`
- **请求方式**：DELETE
- **请求参数**：路径参数 `id` 为收藏夹标识。
- **返回参数**：成功时返回 HTTP 204；目录包含子目录或收藏时返回 `FOLDER_NOT_EMPTY`。

### 查询收藏条目

- **接口路径**：`/api/bookmarks/items`
- **请求方式**：GET
- **请求参数**：支持 `folderId`、`uncategorized=true`、`query`、`page` 和 `pageSize`；`folderId` 与 `uncategorized` 不得同时提交。
- **返回参数**：按更新时间和标识稳定排序的分页收藏列表及总数。

```json
{
  "items": [
    {
      "id": "9",
      "folderId": "1",
      "itemType": "link",
      "title": "Flutter 布局说明",
      "description": "稍后整理",
      "sourceUrl": "https://example.com/flutter?utm_source=share",
      "normalizedUrl": "https://example.com/flutter",
      "sourceHost": "example.com",
      "metadata": {},
      "updatedAt": "2026-10-26T01:11:00.000Z"
    }
  ],
  "total": 1,
  "page": 1,
  "pageSize": 20
}
```

### 创建收藏条目

- **接口路径**：`/api/bookmarks/items`
- **请求方式**：POST
- **请求参数**：`sourceUrl` 为必填 HTTP/HTTPS 链接；`folderId`、`title` 和 `description` 可为空；检测到重复后可提交 `allowDuplicate: true` 明确继续保存。
- **返回参数**：创建后的收藏条目；未确认的重复链接返回 HTTP 409、错误码 `DUPLICATE_BOOKMARK` 及已有条目摘要。

```json
{
  "sourceUrl": "https://example.com/flutter?utm_source=share",
  "title": "Flutter 布局说明",
  "description": "稍后整理",
  "folderId": "1",
  "allowDuplicate": false
}
```

### 获取单条收藏

- **接口路径**：`/api/bookmarks/items/:id`
- **请求方式**：GET
- **请求参数**：路径参数 `id` 为收藏条目标识。
- **返回参数**：当前用户拥有的收藏条目对象；不存在或不属于当前用户时返回 404。

### 更新收藏条目

- **接口路径**：`/api/bookmarks/items/:id`
- **请求方式**：PATCH
- **请求参数**：可提交 `sourceUrl`、`folderId`、`title` 或 `description`；`folderId: null` 表示移动到未分类。
- **返回参数**：更新后的收藏条目对象。

```json
{
  "folderId": null,
  "title": "新的标题"
}
```

### 删除收藏条目

- **接口路径**：`/api/bookmarks/items/:id`
- **请求方式**：DELETE
- **请求参数**：路径参数 `id` 为收藏条目标识。
- **返回参数**：成功时返回 HTTP 204。

## 版本记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-10-26 | 202610260111 | 新增 Android 与 Web 共用的嵌套收藏夹、链接收藏、搜索、重复提示和跨端管理规格 |
