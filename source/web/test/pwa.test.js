import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";

const publicFile = (name) => new URL(`../public/${name}`, import.meta.url);
const manifest = JSON.parse(readFileSync(publicFile("manifest.webmanifest"), "utf8"));

test("PWA 清单和图标可从部署子路径解析", () => {
  const base = new URL("https://example.com/wwjing/manifest.webmanifest");
  assert.equal(new URL(manifest.start_url, base).pathname, "/wwjing/");
  assert.equal(new URL(manifest.scope, base).pathname, "/wwjing/");
  assert.equal(manifest.display, "standalone");
  for (const size of [192, 512]) {
    const icon = manifest.icons.find((item) => item.sizes === `${size}x${size}`);
    assert.ok(icon);
    const png = readFileSync(publicFile(icon.src));
    assert.equal(png.readUInt32BE(16), size);
    assert.equal(png.readUInt32BE(20), size);
    assert.equal(new URL(icon.src, base).pathname, `/wwjing/pwa-${size}.png`);
  }
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  assert.match(html, /href="%BASE_URL%manifest\.webmanifest"/);
});

test("Service Worker 只处理应用导航，断网返回提示", async () => {
  const listeners = {};
  let fetchImpl = () => Promise.resolve(new Response("在线"));
  const self = {
    location: { origin: "https://example.com" },
    registration: { scope: "https://example.com/wwjing/" },
    addEventListener: (type, handler) => { listeners[type] = handler; }
  };
  runInNewContext(readFileSync(publicFile("sw.js"), "utf8"), {
    self, URL, Response, fetch: (...args) => fetchImpl(...args)
  });
  function dispatch(url, mode) {
    let response;
    listeners.fetch({ request: { url, mode }, respondWith: (value) => { response = value; } });
    return response;
  }
  assert.equal(await (await dispatch("https://example.com/wwjing/tools/bookmarks", "navigate")).text(), "在线");
  assert.equal(dispatch("https://example.com/api/bookmarks", "cors"), undefined);
  assert.equal(dispatch("https://example.com/api/bookmarks", "navigate"), undefined);
  assert.equal(dispatch("https://example.com/wwjing/assets/app.js", "cors"), undefined);
  fetchImpl = () => Promise.reject(new Error("offline"));
  const offline = await dispatch("https://example.com/wwjing/office", "navigate");
  assert.equal(offline.status, 503);
  assert.match(await offline.text(), /请检查网络或服务端连接/);
});
