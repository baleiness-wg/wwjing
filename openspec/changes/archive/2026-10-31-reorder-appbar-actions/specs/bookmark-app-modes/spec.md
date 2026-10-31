# Spec Delta

## MODIFIED Requirements

### Requirement: 标准 Material 交互组件

统一收藏客户端 SHALL 优先使用 Flutter 官方 Material 3 交互组件呈现操作栏按钮、卡片和单选状态。kitchen 模式下随机按钮 SHALL 放置在左侧标题右侧紧挨着；新建收藏加号按钮与批量编辑按钮 SHALL 集中放置在 AppBar 右侧操作区。

#### Scenario: 展示收藏主操作

- **WHEN** 用户打开收藏主页
- **THEN** kitchen 模式下随机按钮位于标题右侧紧邻位置；页面右上角集中展示新建加号按钮及编辑操作按钮

#### Scenario: 点击收藏新建按钮附带当前目录上下文

- **WHEN** 用户在某个特定文件夹内点击 AppBar 右上角的新建收藏加号按钮
- **THEN** 客户端打开新建收藏表单，且目标目录默认预选为该文件夹

### Requirement: kitchen 随机推荐入口

kitchen 模式 SHALL 在收藏主页提供随机按钮；用户触发随机操作时，弹窗中的目录范围勾选 SHALL 依据当前所在目录自适应预选。

#### Scenario: 在全部收藏触发随机推荐

- **WHEN** 用户在“全部收藏”视图点击随机按钮
- **THEN** 目录范围选择弹窗默认全选所有可用目录

#### Scenario: 在指定文件夹触发随机推荐

- **WHEN** 用户在特定文件夹视图内点击随机按钮
- **THEN** 目录范围选择弹窗默认仅勾选当前文件夹
