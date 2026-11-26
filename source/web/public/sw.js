// 仅处理页面导航：业务请求及静态资源始终走网络，不保存用户数据。
const offlinePage = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#155e56">
  <title>Whaleland - 无法连接</title>
  <style>
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f5f7f4; color: #25343a; font-family: "Segoe UI", "Microsoft YaHei", sans-serif; }
    main { padding: 32px; text-align: center; }
    h1 { color: #155e56; font-size: 24px; }
    button { padding: 10px 24px; border: 0; border-radius: 8px; background: #155e56; color: white; font: inherit; cursor: pointer; }
  </style>
</head>
<body><main><h1>暂时无法连接 Whaleland</h1><p>请检查网络或服务端连接，然后重试。</p><button onclick="location.reload()">重新连接</button></main></body>
</html>`;

self.addEventListener("install", (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || !url.pathname.startsWith(new URL(self.registration.scope).pathname)) return;

  event.respondWith(fetch(event.request).catch(() => new Response(offlinePage, {
    status: 503,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" }
  })));
});
