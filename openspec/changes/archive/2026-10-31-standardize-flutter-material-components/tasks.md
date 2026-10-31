# Tasks

## 1. 规格与备份准备

- [x] 1.1 将 `source/flutter_bookmark/lib/main.dart`、`widgets/home_page.dart`、`widgets/bookmark_form.dart`、`widgets/bookmark_item_card.dart`、相关测试和 `specs/bookmark-app-modes/spec.md` 备份到 `backups/bookmark/`；验证备份可读且未覆盖既有备份。
- [x] 1.2 更新中文模块规格的页面布局约束和版本记录，写明官方 Material 组件优先、可拖动主操作及目录标准单选行为；核对接口章节保持不变。

## 2. 官方悬浮主操作

- [x] 2.1 将主页手工拼装的“收藏链接”视觉替换为 `FloatingActionButton.extended`，保留 `Positioned`、页面边界约束和单一点击入口；通过 Widget 测试验证控件类型、图标、标签和点击打开草稿。
- [x] 2.2 调整 FAB 的拖动手势判定，确保有效拖动后不打开草稿且控件停留在页面范围内；通过 Widget 测试分别模拟点击和拖动并验证状态结果。

## 3. 官方目录选择组件

- [x] 3.1 将收藏表单的目录入口改为官方 Card/ListTile 组合，显示文件夹图标、当前目录和进入箭头；通过 Widget 测试验证点击仍打开目录选择器且当前选择可见。
- [x] 3.2 使用 `RadioGroup<String>` 和 `RadioListTile<String>` 替换 `_FolderPickerTile` 的手写选中背景与勾选图标，保留最多 8 层缩进和单行省略；通过 Widget/语义测试验证同时只有一个选中项。
- [x] 3.3 保留“未分类”的空值映射及选中目录下新建子目录行为；通过 Widget 测试验证确认未分类后 folderId 为 null、选择嵌套目录后写回 ID、新目录使用当前父 ID。

## 4. 官方卡片与主题统一

- [x] 4.1 使用官方 `Card.filled`/`Card.outlined` 和全局 `CardThemeData`/`ListTileThemeData` 统一收藏条目、子目录和目录选择区域，删除重复的手写卡片外观；通过现有响应式测试和快照式结构断言验证间距、标题及操作入口仍存在。
- [x] 4.2 保留 `BookmarkCover` 的网络图片与来源占位逻辑，以及普通/编辑/随机三种卡片能力开关；通过 Widget 测试验证封面失败回退、编辑 checkbox/菜单和随机卡片精简状态。

## 5. 集成验证与版本收尾

- [x] 5.1 运行 `dart format`、`flutter analyze` 和全部 `flutter test`，修复组件替换造成的 lint、布局溢出或测试回归，验证手机和 Pad 测试尺寸均通过。
- [x] 5.2 分别执行 kitchen 与 star debug APK 构建，验证 flavor/APP_TYPE 配对构建成功且未修改 Android、Node 或依赖清单。
- [x] 5.3 更新 `source/flutter_bookmark/build.json`、`main.dart` BUILD_TIME 和模块规格版本号为当前时间，并核对 `git diff --check` 与 `openspec validate standardize-flutter-material-components --strict` 通过。

## Workflow follow-up

- 实现和评审完成后同步 delta spec，并归档该 OpenSpec 变更。

## 6. 树级菜单与操作菜单统一

- [x] 6.1 抽取唯一的官方 Material 目录树选择器，统一收藏表单、单条移动、批量移动和目录移动的 RadioGroup/RadioListTile、缩进、确认与取消行为；通过 Widget 测试验证四个入口使用相同组件及各自目标限制。
- [x] 6.2 将目录新增改为先选择父目录、再从统一操作菜单触发独立名称 AlertDialog，创建成功后选择新目录；通过测试验证根目录和子目录创建的 parentId 及返回选择。
- [x] 6.3 统一收藏卡片、目录项和根目录入口的 PopupMenuButton、更多图标及带图标菜单项，危险操作使用一致错误色；通过 Widget 测试验证菜单结构、文字和图标一致。
- [x] 6.4 更新中文模块规格与版本信息，重新运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 7. 拖放移动反馈修复

- [x] 7.1 将目录内容查询改为只包含当前目录直接归属条目，确保拖入子目录后条目从当前列表消失；通过 API 状态测试验证移动 PATCH 和后续刷新不请求后代条目。
- [x] 7.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 8. 目录切换视觉一致性

- [x] 8.1 目录切换时立即清空旧列表并进入加载状态，使用请求序号忽略滞后的旧目录响应；通过状态测试验证无旧卡片残影和响应覆盖。
- [x] 8.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 9. 官方编辑选择模式

- [x] 9.1 使用官方 CheckboxListTile 替换编辑模式的手工 Checkbox/封面组合，整行切换选择并隐藏单项操作菜单；通过 Widget 测试验证标准组件和批量操作入口。
- [x] 9.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 10. 批量操作布局

- [x] 10.1 将编辑模式改为左上角取消、右上角保存退出，右下角仅显示移动和删除按钮，并在无选择时禁用；通过 Widget 测试验证布局和退出行为。
- [x] 10.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 11. 主页与目录选择器操作精简

- [x] 11.1 移除主页 AppBar 刷新按钮并保留下拉刷新；将目录选择器右上角更多菜单替换为直接创建文件夹 IconButton，通过 Widget 测试验证。
- [x] 11.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 12. 目录树内联新增

- [x] 12.1 将目录选择器新增目录改为当前选中节点下方的 ListTile/TextField 内联命名，支持确认和取消，创建后刷新并自动选中新目录；通过 Widget 测试验证父目录和窗口保持。
- [x] 12.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 13. 内联新增操作按钮

- [x] 13.1 将内联新增目录的取消和确认按钮缩为紧凑居中图标，确认改为无背景绿色对勾；通过 Widget 测试验证尺寸、颜色和交互。
- [x] 13.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 14. 目录树高亮选择

- [x] 14.1 使用官方 ListTile.selected 整行高亮替换目录树 Radio 圆点，保持唯一选中、层级缩进和内联新增位置；通过 Widget 测试验证无 Radio 且仅一个高亮项。
- [x] 14.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。

## 15. 目录选中文字高亮

- [x] 15.1 移除目录选中背景色，仅使用主题色高亮文字和文件夹图标，保持唯一选中和无障碍语义；通过 Widget 测试验证样式。
- [x] 15.2 更新模块规格与构建版本，运行 format、analyze、全部测试、双 flavor 构建、diff check 和 OpenSpec strict validation。
