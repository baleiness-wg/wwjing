# Whaleland Web

## 桌面 PWA

- 运行 `npm install` 和 `npm run build`，将 `dist/` 发布到 `/wwjing/`，并将 `/api`（包括 Office WebSocket）转发到现有服务端。
- 服务端须将 `/wwjing/` 下的前端路由回退到 `index.html`，并正确提供 `manifest.webmanifest`、`sw.js` 和图标文件；建议对 HTML 和 `sw.js` 禁止长期缓存。
- 通过 HTTPS 访问；开发测试可使用 `localhost`。PWA 注册在生产构建中启用，可使用 `npm run preview` 本机验证。
- 在 Chrome 或 Edge 打开网站，通过地址栏安装按钮或浏览器菜单安装 Whaleland，之后可从桌面或开始菜单打开独立窗口。
- 功能需要连接现有服务端；断网时显示连接提示。页面及业务数据不由 Service Worker 缓存，重新加载即可获取最新版本。
- 桌面图标由 `public/whale.svg` 生成透明 PNG；更新图标后若桌面仍显示旧图标，请关闭应用并重新安装，或刷新系统图标缓存。
