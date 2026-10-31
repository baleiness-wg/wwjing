# bookmark-app-modes 模块规格说明

- 版本：202610310541
- 最后更新：2026-10-31
- 模块名称：bookmark-app-modes（统一收藏客户端模式）

---

## 业务概述

bookmark-app-modes 模块将厨房收藏和星标收藏收敛到 `source/flutter_bookmark/` 单一 Android Flutter 工程。构建者必须通过 `APP_TYPE=kitchen` 或 `APP_TYPE=star` 选择应用模式，两种模式共享登录、分享、剪贴板、目录和收藏管理能力，同时保持应用身份与服务端收藏空间隔离。

## 核心业务流程

- kitchen flavor 必须与 `APP_TYPE=kitchen` 配对，显示“微微鲸厨房”并只访问 `cookie` 空间。
- star flavor 必须与 `APP_TYPE=star` 配对，显示“微微鲸星标”并只访问 `star` 空间。
- 缺少 `APP_TYPE`、值不受支持或与 flavor 不匹配时，构建或启动必须明确失败，不得静默切换模式。
- kitchen 用户可点击“今天吃什么”随机按钮，从当前账号的 `cookie` 空间获取一条随机收藏；star 模式不显示该入口。
- 随机结果使用低高度弹窗显示一个与列表视觉一致的卡片，不显示 checkbox、拖拽和编辑、移动、删除操作，点击卡片使用统一平台跳转。
- Bilibili、小红书和抖音链接优先使用对应 App 的 HTTPS App Link 或 Deep Link，失败后打开 App 首页，目标 App 不可用时才回退系统外部链接。
- 小红书短链保存前必须通过元数据接口解析成完整笔记 URL，并原样保留服务端返回的分享查询参数；解析失败时保留表单并阻止保存短链。
- 合并不迁移 `cookie` 或 `star` 数据，用户安装对应新应用并登录后继续读取原空间数据。

## 页面布局约束

- kitchen 主页在 AppBar 显示“今天吃什么”随机按钮，请求进行中禁止重复点击。
- 随机弹窗内容高度不得扩展为全屏，主体只包含标题和一个收藏卡片。
- 随机卡片显示与主页一致的封面、标题和来源信息，但不显示选择框和操作菜单。
- star 主页不得显示随机按钮，也不得发起随机菜谱请求。
- 两种模式延续既有 Material 3 风格和 Pad 宽屏目录布局。

## 接口说明

### 获取随机厨房收藏

- **接口路径**：`/api/bookmarks/random?space=cookie`
- **请求方式**：GET
- **请求参数**：查询参数 `space` 必须为 `cookie`；请求头携带 `Authorization: Bearer <token>`。
- **返回参数**：`item` 为当前用户随机收藏对象；没有可选收藏时为 `null`。

```json
{
  "item": {
    "id": "7",
    "space": "cookie",
    "folderId": "2",
    "title": "晚餐",
    "description": null,
    "coverUrl": "https://example.com/cover.jpg",
    "sourceUrl": "https://example.com/meal",
    "sourceHost": "example.com"
  }
}
```

```json
{
  "item": null
}
```

### 解析收藏链接元数据

- **接口路径**：`/api/bookmarks/metadata`
- **请求方式**：POST
- **请求参数**：JSON 字段 `sourceUrl` 为待解析的 HTTP/HTTPS 链接；请求头携带 `Authorization: Bearer <token>`。
- **返回参数**：`metadata.finalUrl` 为跟随安全重定向后的完整 URL，并同时返回可空标题、描述和封面 URL。

```json
{
  "sourceUrl": "https://xhslink.cn/o/example"
}
```

```json
{
  "metadata": {
    "finalUrl": "https://www.xiaohongshu.com/discovery/item/example?xsec_token=token&share_id=id",
    "title": "示例笔记",
    "description": null,
    "coverUrl": null
  }
}
```

## 版本记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-10-31 | 202610310541 | 合并 kitchen 与 star Flutter 工程，增加编译期模式、kitchen 随机推荐、统一平台跳转和小红书短链保存前解析 |
