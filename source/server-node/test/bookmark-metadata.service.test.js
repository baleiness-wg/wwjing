const test = require("node:test");
const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const { PassThrough } = require("node:stream");
const {
  createMetadataService,
  decodeHtml,
  isPublicAddress,
  parseMetadata
} = require("../src/services/bookmark-metadata.service");

test("metadata parser handles attribute order, entities, precedence, and relative images", () => {
  const html = `
    <title>Fallback &amp; title</title>
    <meta content="Plain description" name="description">
    <meta content="Twitter title" name="twitter:title">
    <meta content="OG &quot;Title&quot;" property="og:title">
    <meta property='og:description' content='A &#x26; B'>
    <meta content="../images/cover.jpg?x=1&amp;y=2" property="og:image">
    <script>"<meta property='og:title' content='Injected'>"</script>`;
  assert.deepEqual(parseMetadata(html, "https://example.com/articles/one"), {
    finalUrl: "https://example.com/articles/one",
    title: 'OG "Title"',
    description: "A & B",
    coverUrl: "https://example.com/images/cover.jpg?x=1&y=2"
  });
  assert.equal(decodeHtml("A&nbsp;B &#169; &#x1f600;"), "A B © 😀");
});

test("metadata parser extracts Douyin embedded cover when social meta is absent", () => {
  const html = `
    <script>window.__INITIAL_STATE__ = {
      "cover": "https:\\u002F\\u002Fp3-sign.douyinvod.com\\u002Ftos-cn-i-0813\\u002Fcover~tplv.webp",
      "title": "示例视频"
    };</script>`;
  assert.equal(
    parseMetadata(html, "https://www.douyin.com/video/123" ).coverUrl,
    "https://p3-sign.douyinvod.com/tos-cn-i-0813/cover~tplv.webp"
  );
});

test("metadata parser extracts Douyin cover url_list data", () => {
  const html = `<script>\"cover\":{\"url_list\":[\"https:\\\/\\\/p3-sign.douyinvod.com\\\/cover.jpg\"]}</script>`;
  assert.equal(
    parseMetadata(html, "https://www.douyin.com/video/456").coverUrl,
    "https://p3-sign.douyinvod.com/cover.jpg"
  );
});

test("metadata parser does not use embedded cover fields from unrelated hosts", () => {
  const html = `<script>{"cover":"https:\\u002F\\u002Fcdn.example.com\\u002Fcover.jpg"}</script>`;
  assert.equal(parseMetadata(html, "https://example.com/article").coverUrl, null);
});

test("SSRF policy rejects non-public IPv4 and IPv6 ranges", () => {
  for (const address of [
    "0.0.0.0", "10.0.0.1", "100.64.0.1", "127.0.0.1", "169.254.1.1",
    "172.16.0.1", "192.168.1.1", "224.0.0.1", "255.255.255.255",
    "::", "::1", "fc00::1", "fe80::1", "ff02::1", "::ffff:127.0.0.1"
  ]) assert.equal(isPublicAddress(address), false, address);
  assert.equal(isPublicAddress("8.8.8.8"), true);
  assert.equal(isPublicAddress("2606:4700:4700::1111"), true);
});

function mockRequest(responses, requested) {
  return (url, options, callback) => {
    requested.push(url.toString());
    options.lookup(url.hostname, { all: true }, (error, addresses) => {
      assert.ifError(error);
      assert.ok(addresses.length > 0);
    });
    const request = new EventEmitter();
    request.setTimeout = () => request;
    request.destroy = (error) => request.emit("error", error);
    request.end = () => {
      const responseData = responses.shift();
      const response = new PassThrough();
      response.statusCode = responseData.statusCode;
      response.headers = responseData.headers;
      response.resume = response.resume.bind(response);
      callback(response);
      response.end(responseData.body || "");
    };
    return request;
  };
}

test("metadata fetch revalidates redirect targets and returns parsed contract", async () => {
  const hosts = [];
  const requested = [];
  const fetchMetadata = createMetadataService({
    lookup: async (hostname) => {
      hosts.push(hostname);
      return [{ address: hostname === "start.example" ? "93.184.216.34" : "1.1.1.1", family: 4 }];
    },
    request: mockRequest([
      { statusCode: 302, headers: { location: "https://final.example/page" } },
      {
        statusCode: 200,
        headers: { "content-type": "text/html; charset=utf-8" },
        body: '<meta property="og:title" content="Final"><meta property="og:image" content="/cover.png">'
      }
    ], requested)
  });
  assert.deepEqual(await fetchMetadata({ sourceUrl: "https://start.example/path" }), {
    finalUrl: "https://final.example/page",
    title: "Final",
    description: null,
    coverUrl: "https://final.example/cover.png"
  });
  assert.deepEqual(hosts, ["start.example", "final.example"]);
  assert.deepEqual(requested, ["https://start.example/path", "https://final.example/page"]);
});

test("metadata requests use browser-compatible headers for dynamic sites", async () => {
  let requestHeaders;
  const fetchMetadata = createMetadataService({
    lookup: async () => [{ address: "93.184.216.34", family: 4 }],
    request: (url, options, callback) => {
      requestHeaders = options.headers;
      return mockRequest([{
        statusCode: 200,
        headers: { "content-type": "text/html" },
        body: "<title>Example</title>"
      }], [])(url, options, callback);
    }
  });
  await fetchMetadata({ sourceUrl: "https://example.com/video" });
  assert.match(requestHeaders["User-Agent"], /^Mozilla\/5\.0/);
  assert.equal(requestHeaders.Referer, "https://www.douyin.com/");
});

test("metadata parser cleans nested proxy url for Xiaohongshu covers", () => {
  const html1 = '<meta property="og:image" content="https://ci.xiaohongshu.com/http://sns-webpic-qc.xhscdn.com/notes_pre_post/1040g.jpg?imageMogr2">';
  const res1 = parseMetadata(html1, "https://www.xiaohongshu.com/discovery/item/12345");
  assert.equal(res1.coverUrl, "https://sns-webpic-qc.xhscdn.com/notes_pre_post/1040g.jpg?imageMogr2");

  const html2 = '<meta property="og:image" content="https://ci.xiaohongshu.com/http%3A%2F%2Fsns-img-qc.xhscdn.com%2Fphoto%2Ftest.png">';
  const res2 = parseMetadata(html2, "https://www.xiaohongshu.com/discovery/item/12345");
  assert.equal(res2.coverUrl, "https://sns-img-qc.xhscdn.com/photo/test.png");

  const html3 = '<meta property="og:image" content="https://ci.xiaohongshu.com/https://sns-webpic-qc.xhscdn.com/265/abc.jpg">';
  const res3 = parseMetadata(html3, "https://www.xiaohongshu.com/discovery/item/12345");
  assert.equal(res3.coverUrl, "https://sns-webpic-qc.xhscdn.com/265/abc.jpg");
});

test("metadata fetch blocks a redirect resolving to a private address before connecting", async () => {
  let requests = 0;
  const fetchMetadata = createMetadataService({
    lookup: async (hostname) => [{
      address: hostname === "public.example" ? "93.184.216.34" : "127.0.0.1",
      family: 4
    }],
    request: mockRequest([
      { statusCode: 302, headers: { location: "http://internal.example/admin" } }
    ], { push() { requests += 1; } })
  });
  await assert.rejects(
    fetchMetadata({ sourceUrl: "https://public.example" }),
    (error) => error.code === "METADATA_TARGET_BLOCKED" && error.status === 400
  );
  assert.equal(requests, 1);
});
