import { request } from "./http";

export function getFolders() {
  return request("/api/folders");
}

export function createFolder(payload) {
  return request("/api/folders", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
