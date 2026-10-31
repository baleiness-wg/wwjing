# Spec Delta

## MODIFIED Requirements

### Requirement: 编译期应用模式选择

统一收藏客户端 MUST 通过编译期 `APP_TYPE` 选择 `kitchen` 或 `star` 模式，并 SHALL 使用所选模式对应的应用名称、Android 应用身份、收藏空间及原生链接通道；不支持的值 MUST 在启动前或启动时明确失败，不得静默使用另一模式。kitchen 模式应用名称 SHALL 为“疯狂的厨房”，star 模式应用名称 SHALL 为“鲸界”。

#### Scenario: 构建 kitchen 模式

- **WHEN** 使用 `APP_TYPE=kitchen` 构建或运行统一客户端
- **THEN** 应用以“疯狂的厨房”身份运行并只读写 `cookie` 收藏空间

#### Scenario: 构建 star 模式

- **WHEN** 使用 `APP_TYPE=star` 构建或运行统一客户端
- **THEN** 应用以“鲸界”身份运行并只读写 `star` 收藏空间

#### Scenario: APP_TYPE 不受支持

- **WHEN** 构建或启动时提供的 `APP_TYPE` 不是 `kitchen` 或 `star`
- **THEN** 系统给出明确配置错误且不以任一模式继续运行

## ADDED Requirements

### Requirement: 登录页账号注册

统一客户端登录页 SHALL 提供明确的“注册”操作；用户提交有效的用户名与密码后，客户端 SHALL 调用服务端注册接口创建账号，并在注册成功后自动执行登录进入主界面，失败时 SHALL 显示可读错误提示且不丢失已输入内容。

#### Scenario: 成功注册新账号

- **WHEN** 未登录用户在登录页输入新的用户名与密码并点击“注册”
- **THEN** 客户端请求服务端注册接口创建用户，成功后自动完成登录并跳转到收藏主界面

#### Scenario: 注册用户名已存在

- **WHEN** 用户尝试注册已存在的用户名
- **THEN** 客户端停留在当前界面，显示用户名已存在错误提示并保留已输入文本

#### Scenario: 提交空用户名或密码注册

- **WHEN** 用户在用户名或密码为空时点击“注册”
- **THEN** 客户端阻止提交并提示必须输入用户名和密码

### Requirement: 应用定制图标

Android 客户端 SHALL 为 `kitchen` 和 `star` 模式分别配置符合主题的专用启动图标；kitchen 模式必须使用烹饪/做饭元素图标，star 模式必须使用鲸鱼元素图标，且在不同屏幕密度下清晰呈现。

#### Scenario: 安装 kitchen 模式图标

- **WHEN** 用户在 Android 设备上安装并查看 kitchen 模式应用
- **THEN** 系统启动器显示做饭/厨房主题的应用图标，应用标签显示为“疯狂的厨房”

#### Scenario: 安装 star 模式图标

- **WHEN** 用户在 Android 设备上安装并查看 star 模式应用
- **THEN** 系统启动器显示鲸鱼主题的应用图标，应用标签显示为“鲸界”
