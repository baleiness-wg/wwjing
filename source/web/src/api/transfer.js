import { request } from "./http";

export function getTransferContent() {
  return request("/api/transfer/content");
}

export function saveTransferText(text) {
  return request("/api/transfer/content/text", {
    method: "POST",
    body: JSON.stringify({ text })
  });
}

export function uploadTransferFile(file) {
  const body = new FormData();
  body.append("file", file);
  return request("/api/transfer/content/file", {
    method: "POST",
    body,
    headers: {}
  });
}

export async function downloadTransferFile() {
  const response = await fetch("/api/transfer/content/file", {
    headers: { Authorization: localStorage.getItem("wwjing_token") || "" }
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new Error(error.message || "下载失败");
  }
  return response;
}
