# Design

## Context

参见 `proposal.md` 的动机。统一工程已启用 `useMaterial3: true`，多数页面已经使用 `Scaffold`、`AppBar`、`Card`、`ListTile`、`AlertDialog`、`SearchBar` 和 Material 按钮。需要处理的自写视觉主要集中在主页可拖动主操作的内部外观、收藏表单目录入口和 `_FolderPickerTile` 的选中背景/勾选图标。

当前 Flutter SDK 为 3.47.5，支持 Material 3 官方组件。现有目录选择还承担层级缩进和“在选中目录下新建”能力，不能用简单下拉菜单替代；封面组件承担网络失败后的来源域名回退，也不存在等价的官方单组件。

## Goals / Non-Goals

**Goals:**

- 用官方 Material 3 组件替换重复的手工外观和选中状态实现。
- 保持收藏主操作可拖动、点击和位置约束行为。
- 保持目录树、未分类映射和新建子目录行为。
- 通过主题和官方 Card 变体统一普通列表、目录项及随机结果的视觉层级。
- 增加 Widget 测试，验证组件替换不会造成业务回退。

**Non-Goals:**

- 不把动态多层目录强行改为只适合固定目的地的完整 `NavigationDrawer`。
- 不移除 `BookmarkCover` 的来源域名回退逻辑。
- 不重写拖放、平台跳转、随机推荐、登录或状态管理。
- 不引入第三方组件库，也不改变 Node 接口和 Android 原生配置。

## Decisions

### 1. 用官方扩展 FAB 承载主操作视觉

保留现有 `Positioned` 和拖动状态计算，仅将内部手工 `Material + Padding + Row` 替换为 `FloatingActionButton.extended`。外层手势继续区分点击与拖动，FAB 提供标准形状、海拔、按压、焦点和语义。

直接使用 `Scaffold.floatingActionButton` 的替代方案代码更少，但会丢失用户拖动定位能力，因此不采用。外层手势必须避免与 FAB 自身点击处理重复：由单一点击路径打开草稿，拖动达到阈值后禁止触发。

### 2. 用标准单选控件替换手绘目录选中项

目录弹窗使用 `RadioGroup<String>` 管理选择，列表项使用 `RadioListTile<String>`。以空字符串作为“未分类”内部值，在确认时映射回 `null`；真实目录使用 ID。层级仍由外围 `Padding` 或 `contentPadding` 表达，不自行绘制选中背景或尾部勾选图标。

普通 `DropdownMenu` 无法同时承载多层缩进和弹窗内新建目录，因此不采用。新建目录仍使用现有文本框和 `IconButton.filledTonal`，创建父 ID 来自当前单选目录。

### 3. 表单目录入口使用标准 ListTile 语义

将 `InkWell + InputDecorator + Text` 改为官方 `ListTile`，使用文件夹 leading、当前目录 title/subtitle 和 chevron trailing，并放在官方 outlined/filled Card 变体中。该入口明确表达“打开选择器”，避免伪装成可直接输入的文本字段。

只读 `TextFormField` 也可模拟选择框，但仍需要手工处理焦点、光标和下拉语义，不如 `ListTile` 直接。

### 4. 保留领域组件，只统一 Card 变体和主题

`BookmarkItemCard` 继续使用官方 `Card + ListTile`，因为它需要可选 checkbox、封面和菜单，`CheckboxListTile` 无法在不增加更多包装的情况下表达这些组合。根据层级选择 `Card.filled` 或 `Card.outlined`，并尽量在 `ThemeData.cardTheme`、`listTileTheme` 中统一边距和形状。

`BookmarkCover` 保持自定义封装，其内部仍使用官方 `Image.network`、`ClipRRect` 和主题颜色。它属于必要领域行为，而非重复造轮子。

### 5. 不扩大导航改造范围

保留手机 `Drawer` 和宽屏常驻 `FolderNavigation`。顶层目的地虽然可以单独改为 `NavigationDrawerDestination`，但动态目录需要缩进、尾部菜单和任意层级，混合两种选中模型会增加复杂度且收益有限。本次仅统一目录选择弹窗，不重构主导航。

### 6. 抽取唯一目录树选择器

将收藏表单、单条移动、批量移动和目录移动统一到一个公开的 `FolderPickerDialog`。组件固定使用 `AlertDialog + RadioGroup + RadioListTile`，通过参数控制标题、根选项文案、初始值、排除目录和是否允许新增。目录移动传入自身及后代作为排除项，其他入口不复制树渲染代码。

新增目录不再嵌入树选择器顶部。选择器标题区提供统一更多菜单；用户先选择父目录，再选择“新增子目录”，随后打开独立 `AlertDialog` 输入名称。创建成功后返回新目录 ID，使调用方立即选中新目录。

### 7. 统一尾部操作菜单

收藏卡片和目录列表使用同一个菜单项构造方式：`PopupMenuButton<String>`、`more_vert` 图标、统一 tooltip，以及包含 leading icon 和文字的菜单项。删除项使用错误色图标和文字；移动、编辑、重命名等相同行为使用一致图标。根目录新增入口也改用同形态操作菜单，不再单独显示无上下文的创建图标。

## Risks / Trade-offs

- [FAB 内外手势竞争导致点击失效或拖动误触] → 只保留一个业务点击入口，并用 Widget 测试分别模拟点击与拖动。
- [RadioListTile 默认密度使 8 层目录过宽] → 保留层级缩进但限制单层缩进值，标题使用单行省略，并在 Pad/手机宽度测试。
- [官方 Card 默认间距或海拔改变现有布局] → 通过 `CardThemeData` 和显式 `margin` 统一，保留现有列表间距断言。
- [组件类型变化使现有测试过度依赖内部结构] → 测试优先按 key、文本、语义和业务结果查找，避免依赖官方组件内部树。
- [多个入口复用选择器时返回值语义混淆] → 统一使用空字符串表示根/未分类，取消返回 null，由调用方按业务映射。

## Migration Plan

1. 备份将修改的 Flutter 文件和模块规格。
2. 先替换主操作 FAB 并补充点击/拖动测试。
3. 抽取统一目录选择器并替换收藏表单、单条移动、批量移动和目录移动入口。
4. 将新增目录改为操作菜单触发独立名称窗口，并统一收藏/目录尾部菜单。
5. 统一 Card 变体及主题，运行现有随机、封面、响应式和表单测试。
6. 运行 `dart format`、`flutter analyze`、`flutter test` 以及 kitchen/star debug 构建。
7. 更新模块规格历史、`build.json` 和 BUILD_TIME；若回归则恢复备份并保留现有业务组件。
