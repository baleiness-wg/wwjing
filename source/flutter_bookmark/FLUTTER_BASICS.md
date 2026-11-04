# 给 Vue 2 开发者的 Flutter 入门

本文不把 Flutter 当成一堆 API 来背，而是从你熟悉的 Vue 2 和 Node 出发，解释 Flutter 到底如何运行。

当前项目是一个收藏 App。理解它以后，你应该能回答这些问题：

```text
Flutter 的页面是什么？
一个按钮点击后发生了什么？
状态改变后界面为什么会更新？
Flutter 中的组件如何传数据？
网络请求放在哪里？
页面如何切换？
Android 原生代码如何和 Dart 通信？
```

## 一、先建立正确的认识

Vue 2 是：

```text
HTML 模板
  +
JavaScript data
  +
Vue 响应式系统
  ↓
浏览器 DOM
```

Flutter 是：

```text
Dart 状态
  +
Widget 描述
  +
Flutter 框架
  ↓
原生渲染界面
```

Flutter 没有 HTML，也没有浏览器 DOM。

Flutter 的界面不是：

```text
先创建一个按钮，然后直接修改这个按钮
```

而是：

```text
当前状态是什么
  ↓
根据状态描述界面
  ↓
状态改变
  ↓
重新描述界面
  ↓
Flutter 更新屏幕
```

这是理解 Flutter 最重要的一句话：

> Flutter 是一个由状态重新生成界面描述的 UI 框架。

## 二、和 Vue 2 的对应关系

先看一个 Vue 2 组件：

```vue
<template>
  <button @click="count++">
    {{ count }}
  </button>
</template>

<script>
export default {
  data() {
    return {
      count: 0
    }
  }
}
</script>
```

它的含义是：

```text
count 是状态
模板使用 count
点击按钮修改 count
Vue 发现 count 变化
Vue 更新 DOM
```

Flutter 写法大致是：

```dart
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () {
        setState(() {
          count++;
        });
      },
      child: Text('$count'),
    );
  }
}
```

对应关系：

| Vue 2 | Flutter |
|---|---|
| `template` | `build()` 返回的 Widget 树 |
| `data()` | `State` 中的字段 |
| `methods` | Dart 方法 |
| `@click` | `onPressed` 等回调 |
| Vue 响应式更新 | `setState()` 或状态通知 |
| 组件 | Widget |
| `props` | 构造函数参数 |
| `emit` | 回调函数 |
| Vue Router | Navigator / 路由 |
| Axios | `http` 包和项目的 `ApiClient` |
| `mounted` | `initState()` 后的生命周期阶段 |
| `beforeDestroy` | `dispose()` |
| Vuex/Pinia | Provider、Riverpod、Bloc 等状态方案 |

但有一个重要区别：

```text
Vue 模板是字符串化的 HTML 结构
Flutter build() 是 Dart 代码，直接创建 Widget 对象
```

## 三、Flutter 应用从哪里开始

Flutter 程序从 `lib/main.dart` 的 `main()` 开始：

```dart
void main() {
  runApp(const MyApp());
}
```

你可以把它类比成 Node 的：

```js
const app = express();
app.listen(3000);
```

但两者启动的东西不同：

```text
Node app.listen()  → 启动 HTTP 服务，等待请求
Flutter runApp()   → 启动 UI，等待用户操作
```

当前项目的 `main()` 做了更多准备：

```text
读取应用模式
创建安全 Token 存储
创建 HTTP 客户端
创建全局业务状态
把根 Widget 交给 Flutter
```

简化后是：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.current;
  final tokenStore = SecureTokenStore();
  final api = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    space: config.space,
    tokenStore: tokenStore,
  );
  final state = AppState(
    api: api,
    tokenStore: tokenStore,
    preferences: SharedPreferencesStore(),
  );

  runApp(BookmarkApp(state: state, appConfig: config));
}
```

这些代码要分成两类：

```text
main()、runApp()                  Flutter/Dart 启动流程
AppConfig、ApiClient、AppState     当前项目自己的对象
```

## 四、Flutter 中没有“页面模板”，只有 Widget 树

Vue 页面通常写成：

```vue
<div class="page">
  <header>收藏</header>
  <main>内容</main>
</div>
```

Flutter 写成：

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('收藏'),
  ),
  body: const Text('内容'),
)
```

这段 Dart 代码不是在操作 DOM，而是在构造一棵 Widget 树：

```text
Scaffold
├── AppBar
│   └── Text
└── Text
```

每个 Widget 都是在描述一件事：

```text
Text       显示文字
Row        横向排列子组件
Column     纵向排列子组件
Padding    给子组件加内边距
ListView   显示可滚动列表
Scaffold   组织一个 Material 页面
```

这些 Widget 最终由 Flutter 绘制成 Android/iOS 界面。

## 五、`build()` 的真正含义

Vue 中你写模板，Vue 根据 data 更新 DOM。

Flutter 中你写 `build()`，Flutter 根据状态更新界面：

```dart
@override
Widget build(BuildContext context) {
  if (loading) {
    return const CircularProgressIndicator();
  }

  return const Text('加载完成');
}
```

这段代码不是只执行一次。

当 `loading` 改变后，Flutter 会再次执行 `build()`：

```text
loading=true
  ↓
build() 返回加载圈

loading=false
  ↓
build() 返回“加载完成”
```

所以 `build()` 的本质是：

> 给定当前状态，计算当前应该显示的界面。

不要把 `build()` 理解成“初始化页面”。它更像 Vue 模板的重新计算过程。

## 六、Flutter 中的两种状态

### 1. 组件自己的局部状态

例如收藏表单中的：

```text
输入框内容
是否正在识别
当前选择的文件夹
是否进入编辑模式
```

这些状态只和某个页面有关，可以放在 StatefulWidget 的 State 中：

```dart
class _BookmarkFormState extends State<BookmarkForm> {
  bool recognizing = false;
  String? folderId;
}
```

### 2. 多个页面共享的业务状态

例如：

```text
是否登录
收藏列表
收藏夹列表
当前搜索词
当前编辑草稿
```

这些数据不能只放在某个输入框组件里，因为登录页、首页、编辑页都可能需要它们。

当前项目把它们放在：

```text
features/bookmarks/presentation/bookmark_state.dart
```

类名是：

```dart
class AppState extends ChangeNotifier
```

可以把它类比成 Vuex Store：

```text
AppState ≈ Vuex store
items    ≈ store.state.items
saveDraft() ≈ store action
notifyListeners() ≈ 通知依赖状态的组件更新
```

它不是 Flutter 自动提供的，而是当前项目自己写的业务状态类。

## 七、`setState()` 到底做了什么

局部状态改变时使用：

```dart
setState(() {
  recognizing = true;
});
```

它不是数据库更新，也不是网络请求。

它只做一件事：

```text
告诉 Flutter：这个组件依赖的状态变了，请重新执行它的 build()
```

完整流程：

```text
用户点击“识别”
  ↓
recognizing=true
  ↓
setState()
  ↓
Flutter 重新 build 表单
  ↓
按钮显示加载状态
```

Vue 里修改响应式 data 后 Vue 自动知道要更新。

Flutter 里对于 StatefulWidget 的局部状态，需要通过 `setState()` 明确告诉框架。

## 八、`ChangeNotifier` 和 Provider 的含义

当前项目使用 Provider。先不把它当成复杂框架，只理解成三个动作：

```text
把一个状态对象放到 Widget 树上
让子 Widget 能找到它
状态改变时通知监听者
```

注入：

```dart
ChangeNotifierProvider.value(
  value: state,
  child: const BookmarkApp(),
)
```

这相当于把 `state` 放进一个全局可访问的上下文中。

子组件读取但不监听：

```dart
final state = context.read<AppState>();
```

适合点击按钮时调用方法：

```dart
onPressed: () {
  context.read<AppState>().openDraft();
}
```

子组件读取并监听：

```dart
final state = context.watch<AppState>();
```

适合页面显示状态：

```dart
final state = context.watch<AppState>();
return Text(state.items.length.toString());
```

当 `AppState` 执行：

```dart
notifyListeners();
```

使用 `watch` 的 Widget 会重新构建。

对应 Vue 的理解：

```text
context.read()  ≈ 只调用 store action，不建立响应式依赖
context.watch() ≈ 读取 store state，并建立响应式依赖
```

## 九、当前项目页面是如何切换的

当前项目没有把“登录页跳到首页”完全写成传统的页面跳转，而是根据状态决定根页面：

```dart
if (!state.initialized) {
  return LoadingPage;
}

if (!state.authenticated) {
  return LoginPage;
}

if (state.draft != null) {
  return BookmarkForm;
}

return HomePage;
```

登录流程：

```text
显示 LoginPage
  ↓
用户点击登录
  ↓
调用 AppState.login()
  ↓
请求 Node API
  ↓
保存 JWT
  ↓
authenticated=true
  ↓
notifyListeners()
  ↓
根 Widget 重新 build
  ↓
不再返回 LoginPage，改返回 HomePage
```

新增收藏流程：

```text
显示 HomePage
  ↓
用户点击加号
  ↓
AppState.openDraft()
  ↓
draft 不再为空
  ↓
根 Widget 重新 build
  ↓
改返回 BookmarkForm
```

这和 Vue 中通过 `v-if` 根据状态显示不同组件很像：

```vue
<LoginPage v-if="!authenticated" />
<BookmarkForm v-else-if="draft" />
<HomePage v-else />
```

## 十、Flutter 页面和组件如何传数据

### 父组件传给子组件：构造函数参数

Vue：

```vue
<BookmarkCard :item="item" />
```

Flutter：

```dart
BookmarkItemCard(
  item: item,
  onTap: () => open(item),
)
```

子组件定义参数：

```dart
class BookmarkItemCard extends StatelessWidget {
  const BookmarkItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final BookmarkItem item;
  final VoidCallback onTap;
}
```

对应关系：

```text
Vue props       ≈ Flutter 构造函数参数
Vue $emit       ≈ Flutter 回调函数
```

### 子组件通知父组件：回调函数

```dart
BookmarkItemCard(
  onTap: () {
    _openLink(item);
  },
)
```

子组件点击时执行 `onTap()`，但子组件不需要知道父组件具体怎么处理。

这就是 Flutter 中常见的组件通信方式：

```text
父组件传数据和回调
子组件显示数据并调用回调
```

## 十一、Flutter 中的输入框和保存

当前收藏表单有几个输入框：

```dart
final _url = TextEditingController();
final _title = TextEditingController();
final _description = TextEditingController();
final _coverUrl = TextEditingController();
```

页面：

```dart
TextFormField(controller: _url)
TextField(controller: _title)
TextField(controller: _description)
TextField(controller: _coverUrl)
```

用户输入后，数据先存在 Controller 中：

```text
用户输入
  ↓
TextEditingController.text
  ↓
仍然只在客户端内存中
```

点击保存时，项目代码主动把它们组装成模型：

```dart
final draft = BookmarkDraft(
  sourceUrl: _url.text.trim(),
  title: _title.text.trim(),
  description: _description.text.trim(),
  folderId: _folderId,
  coverUrl: _coverUrl.text.trim(),
);
```

之后才会发送网络请求：

```text
BookmarkDraft
  ↓
AppState.saveDraft()
  ↓
ApiClient.createItem()
  ↓
POST /api/bookmarks/items
```

这里特别容易误解：

```text
_coverUrl.text = 图片地址
```

只代表输入框里有地址，不代表数据库已经有地址。

必须发送：

```text
PATCH /api/bookmarks/items/:id
```

服务端才会写入 `cover_url`。

## 十二、Flutter 中的异步请求

你熟悉 Node 的写法：

```js
app.get('/items', async (req, res) => {
  const items = await service.list();
  res.json(items);
});
```

Flutter 的异步写法很像：

```dart
Future<List<BookmarkItem>> loadItems() async {
  final result = await api.getItems();
  return result.items;
}
```

对应关系：

```text
Node async function  ≈ Dart async 函数
Promise             ≈ Future
await               ≈ await
```

但运行环境不同：

```text
Node 等待数据库或 HTTP 请求
Flutter 等待 API 时还要继续响应用户和绘制界面
```

当前项目加载收藏：

```text
AppState.refresh()
  ↓
ApiClient.getFolders()
  ↓
ApiClient.getItems()
  ↓
把结果写入 folders/items
  ↓
notifyListeners()
  ↓
HomePage 重新 build
```

## 十三、当前项目的 HTTP 分层

你熟悉 Node 的分层：

```text
route
  ↓
controller
  ↓
service
  ↓
model
  ↓
database
```

Flutter 客户端当前大致是：

```text
Widget
  ↓
AppState
  ↓
ApiClient
  ↓
http.Client
  ↓
Node API
```

每一层的职责：

```text
Widget       显示界面、接收点击和输入
AppState     组织一次完整业务操作
ApiClient    拼请求、加 JWT、解析响应
http.Client  真正发送 HTTP
Node API     校验、执行业务、访问数据库
```

例如保存收藏：

```text
BookmarkForm
  ↓ 收集表单
AppState.saveDraft()
  ↓ 组织保存流程
ApiClient.createItem()
  ↓ 组装 HTTP 请求
POST /api/bookmarks/items
  ↓
Node controller/service/model
  ↓
PostgreSQL
```

## 十四、封面识别的完整真实流程

当前项目的封面识别不是 Flutter 自动完成的，而是项目自己实现的业务流程。

### 前端识别

抖音和 B 站：

```text
BookmarkForm
  ↓
DouyinResolver 或 BilibiliResolver
  ↓
外部平台接口
  ↓
BookmarkMetadata
```

普通链接：

```text
BookmarkForm
  ↓
AppState.fetchBookmarkMetadata()
  ↓
ApiClient.getBookmarkMetadata()
  ↓
POST /api/bookmarks/metadata
  ↓
Node 解析网页
  ↓
BookmarkMetadata
```

### 识别结果为什么还要再保存

识别结果第一次只是回到 Flutter 内存：

```text
BookmarkMetadata
  ↓
更新表单中的 title、description、coverUrl
```

这还没有写数据库。

保存后还需要：

```text
POST /api/bookmarks/items
  ↓
拿到 itemId
  ↓
PATCH /api/bookmarks/items/:id
  ↓
cover_url 落库
```

当前项目已经把前端识别结果通过 `Future<BookmarkMetadata?>` 传给保存流程，避免保存后重新解析一次。

## 十五、滚动列表和刷新为什么要分开

无限滚动有两种完全不同的操作。

### 刷新

```text
下拉刷新
  ↓
回到 page=1
  ↓
清空 items
  ↓
请求第一页
  ↓
显示第一页
```

### 加载更多

```text
滚动到接近底部
  ↓
请求 page+1
  ↓
items = 旧 items + 新 items
  ↓
列表继续变长
```

刷新不能继续使用当前页，否则会出现：

```text
已经加载到第 3 页
  ↓
刷新仍请求第 3 页
  ↓
旧列表被第 3 页替换
  ↓
看起来少了很多收藏
```

所以当前 `refresh()` 默认会：

```dart
page = 1;
items = [];
```

## 十六、页面弹窗和页面跳转

### 弹窗

当前项目的文件夹选择是弹窗，不是新页面：

```dart
final folderId = await showFolderPicker(...);
```

内部最后执行：

```dart
Navigator.pop(context, selectedFolderId);
```

所以调用方能拿到结果：

```text
打开弹窗
  ↓
用户选择文件夹
  ↓
关闭弹窗并返回 folderId
  ↓
表单更新 _folderId
```

### 页面导航

Flutter 也可以用 Navigator 进入新页面：

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const DetailPage(),
  ),
);
```

但当前项目的登录页、首页、收藏表单主要通过 `AppState` 状态切换，而不是用 `push` 完成。

## 十七、Android/iOS 原生通信

Flutter 的 Dart 代码不能直接调用 Kotlin 或 Swift。两边需要约定一个通道：

```text
com.baleine.wwjing.bookmark/share
```

Dart 调用原生：

```dart
channel.invokeMethod('openInApp', {
  'url': url,
  'packageName': packageName,
});
```

这里的 `openInApp` 不是 Flutter 固定 API，而是 Dart 和 Kotlin/Swift 共同约定的方法名。

原生调用 Dart：

```text
Android 收到系统分享
  ↓
MainActivity 读取文本
  ↓
调用 shareReceived
  ↓
Dart ShareService 收到文本
  ↓
AppState.openSharedText()
```

可以把 MethodChannel 类比成：

```text
WebView JavaScript Bridge
或 Electron 的 preload bridge
```

## 十八、最重要的学习方法

看 Flutter 代码时，不要先问“这个 API 的名字是什么”，先问下面的问题：

### 1. 这份数据现在在哪里

```text
输入框里？
State 里？
AppState 里？
服务器数据库里？
```

例如：

```text
_coverUrl.text        表单内存
BookmarkDraft         保存前的数据对象
BookmarkMetadata      识别结果对象
PATCH 请求体         正在传输
cover_url             数据库字段
```

### 2. 谁修改了它

```text
用户输入
setState()
notifyListeners()
API 返回
数据库更新
```

### 3. 修改后谁会重新执行

```text
setState()             当前 StatefulWidget 的 build()
notifyListeners()      Provider 监听者的 build()
API 返回               业务代码决定是否通知界面
```

### 4. 当前代码是 Flutter 还是项目封装

```text
TextField()            Flutter Widget
setState()             Flutter 基础能力
context.watch()       Provider 能力
AppState.saveDraft()   项目业务代码
ApiClient.createItem() 项目网络封装
```

## 十九、把当前项目压缩成一句话

当前 Flutter 收藏应用的运行模型是：

```text
main() 创建项目依赖
  ↓
runApp() 启动根 Widget
  ↓
Widget 根据 AppState 显示登录页、首页或收藏表单
  ↓
用户操作调用 AppState 方法
  ↓
AppState 调用 ApiClient 访问 Node API
  ↓
数据变化后 notifyListeners()
  ↓
监听状态的 Widget 重新 build()
  ↓
Flutter 更新原生界面
```

如果使用 Vue 2 的语言重新说一遍：

```text
Widget 树 ≈ Vue 模板树
State     ≈ data
AppState  ≈ Vuex store
Provider  ≈ store 注入和响应式订阅
build()   ≈ 根据当前状态重新计算模板
ApiClient ≈ Axios 封装
Navigator ≈ Vue Router
MethodChannel ≈ 原生 Bridge
```

但 Flutter 不生成 HTML，也不操作 DOM。它使用 Dart 重新描述 Widget 树，再由 Flutter 绘制到 Android 或 iOS 屏幕上。
