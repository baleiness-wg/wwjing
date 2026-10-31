# Spec Delta

## ADDED Requirements

### Requirement: Web 端收藏多空间与厨房入口支持

Web 端 SHALL 在工具-》收藏夹目录下分别提供“疯狂的厨房”与“鲸界”两个入口，对应路由分别为 `/tools/bookmarks/kitchen`（读写 `cookie` 空间）与 `/tools/bookmarks/star`（读写 `star` 空间）；访问既有 `/tools/bookmarks` 路由时 SHALL 兼容重定向到默认入口。

#### Scenario: 进入疯狂的厨房

- **WHEN** 用户在 Web 端访问 `/tools/bookmarks/kitchen`
- **THEN** 页面展示“疯狂的厨房”标题与烹饪主题描述，目录树和收藏列表仅加载并操作 `cookie` 空间数据

#### Scenario: 进入鲸界

- **WHEN** 用户在 Web 端访问 `/tools/bookmarks/star`
- **THEN** 页面展示“鲸界”标题与收藏整理描述，目录树和收藏列表仅加载并操作 `star` 空间数据

#### Scenario: 访问既有收藏夹路由

- **WHEN** 用户在 Web 端访问 `/tools/bookmarks`
- **THEN** 页面兼容导航到指定收藏空间，不发生页面 404 或白屏错误

### Requirement: Web 端厨房模式支持随机菜谱

Web 端在“疯狂的厨房”模式下 SHALL 在工具栏提供“今天吃什么”随机推荐按钮，点击后可向 `/api/bookmarks/random?space=cookie` 发起随机菜谱抽取并在弹窗中展示抽取结果；“鲸界”模式下 MUST 不显示该随机推荐按钮。

#### Scenario: 厨房模式触发随机菜谱

- **WHEN** 用户在“疯狂的厨房”页面点击“今天吃什么”且存在菜谱收藏
- **THEN** 系统请求随机菜谱接口并展示随机卡片弹窗，支持点击跳转原链接

#### Scenario: 鲸界模式隐藏随机按钮

- **WHEN** 用户在“鲸界”收藏页面浏览收藏
- **THEN** 页面工具栏不显示“今天吃什么”随机按钮
