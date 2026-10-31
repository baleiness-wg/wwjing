# Spec Delta

## MODIFIED Requirements

### Requirement: 编译期应用模式选择

统一收藏客户端 MUST 通过编译期 `APP_TYPE` 选择 `kitchen` 或 `star` 模式，并 SHALL 使用所选模式对应的应用名称、Android 应用身份、收藏空间及原生链接通道；不支持的值 MUST 在启动前或启动时明确失败，不得静默使用另一模式。

#### Scenario: 构建 kitchen 模式

- **WHEN** 使用 `APP_TYPE=kitchen` 构建或运行统一客户端
- **THEN** 应用以 kitchen 身份运行并只读写 `kitchen` 收藏空间

#### Scenario: 构建 star 模式

- **WHEN** 使用 `APP_TYPE=star` 构建或运行统一客户端
- **THEN** 应用以 star 身份运行并只读写 `star` 收藏空间

#### Scenario: APP_TYPE 不受支持

- **WHEN** 构建或启动时提供的 `APP_TYPE` 不是 `kitchen` 或 `star`
- **THEN** 系统给出明确配置错误且不以任一模式继续运行

### Requirement: 合并后保持共享收藏能力

两种模式 SHALL 提供合并前已有的登录、Android 系统分享、剪贴板识别、目录导航、收藏增删改查、搜索及链接打开能力；模式切换不得改变服务端已有收藏数据。

#### Scenario: kitchen 使用共享功能

- **WHEN** 用户以 kitchen 模式登录并管理收藏
- **THEN** 用户可以使用共享收藏功能且操作仅影响 `kitchen` 空间

#### Scenario: star 使用共享功能

- **WHEN** 用户以 star 模式登录并管理收藏
- **THEN** 用户可以使用共享收藏功能且操作仅影响 `star` 空间

#### Scenario: 使用既有收藏数据

- **WHEN** 用户首次使用合并后的对应模式登录
- **THEN** 应用显示该账号在相应空间中已有的目录和收藏，无需复制或迁移条目

### Requirement: kitchen 随机推荐入口

kitchen 模式 SHALL 在收藏主页提供随机按钮；用户触发随机操作时，弹窗中的目录范围勾选 SHALL 依据当前所在目录自适应预选。

#### Scenario: 在全部收藏触发随机推荐

- **WHEN** 用户在“全部收藏”视图点击随机按钮
- **THEN** 目录范围选择弹窗默认全选所有可用目录

#### Scenario: 在指定文件夹触发随机推荐

- **WHEN** 用户在特定文件夹视图内点击随机按钮
- **THEN** 目录范围选择弹窗默认仅勾选当前文件夹

#### Scenario: kitchen 请求随机收藏

- **WHEN** kitchen 用户点击随机按钮且 `kitchen` 空间存在收藏
- **THEN** 客户端请求一条随机收藏并打开“今天吃什么”弹窗展示该条目

#### Scenario: kitchen 空间没有收藏

- **WHEN** kitchen 用户点击随机按钮且随机接口返回空结果
- **THEN** 客户端提示暂无可推荐内容且不显示空白卡片

#### Scenario: cookie 空间没有收藏

- **WHEN** 旧客户端仍以 `cookie` 空间请求随机菜谱
- **THEN** 服务端返回 `INVALID_SPACE`，客户端显示可理解的失败提示且不展示空白卡片

#### Scenario: 随机请求失败

- **WHEN** 随机接口因网络、认证或服务端错误失败
- **THEN** 客户端保留当前页面并显示可理解的失败提示

#### Scenario: star 不提供随机入口

- **WHEN** 用户以 star 模式打开收藏主页
- **THEN** 页面不显示随机按钮且不会请求随机菜谱接口

### Requirement: Web 端收藏多空间与厨房入口支持

Web 端 SHALL 在工具-》收藏夹目录下分别提供“疯狂的厨房”与“鲸界”两个入口，对应路由分别为 `/tools/bookmarks/kitchen`（读写 `kitchen` 空间）与 `/tools/bookmarks/star`（读写 `star` 空间）；访问既有 `/tools/bookmarks` 路由时 SHALL 兼容重定向到默认入口。

#### Scenario: 进入疯狂的厨房

- **WHEN** 用户在 Web 端访问 `/tools/bookmarks/kitchen`
- **THEN** 页面展示“疯狂的厨房”标题与烹饪主题描述，目录树和收藏列表仅加载并操作 `kitchen` 空间数据

#### Scenario: 进入鲸界

- **WHEN** 用户在 Web 端访问 `/tools/bookmarks/star`
- **THEN** 页面展示“鲸界”标题与收藏整理描述，目录树和收藏列表仅加载并操作 `star` 空间数据

#### Scenario: 访问既有收藏夹路由

- **WHEN** 用户在 Web 端访问 `/tools/bookmarks`
- **THEN** 页面兼容导航到指定收藏空间，不发生页面 404 或白屏错误

### Requirement: Web 端厨房模式支持随机菜谱

Web 端在“疯狂的厨房”模式下 SHALL 在工具栏提供“今天吃什么”随机推荐按钮，点击后可向 `/api/bookmarks/random?space=kitchen` 发起随机菜谱抽取并在弹窗中展示抽取结果；“鲸界”模式下 MUST 不显示该随机推荐按钮。

#### Scenario: 厨房模式触发随机菜谱

- **WHEN** 用户在“疯狂的厨房”页面点击“今天吃什么”且存在菜谱收藏
- **THEN** 系统请求随机菜谱接口并展示随机卡片弹窗，支持点击跳转原链接

#### Scenario: 鲸界模式隐藏随机按钮

- **WHEN** 用户在“鲸界”收藏页面浏览收藏
- **THEN** 页面工具栏不显示“今天吃什么”随机按钮
