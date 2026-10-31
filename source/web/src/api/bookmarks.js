import { request } from "./http.js";

const baseUrl = "/api/bookmarks";

export function getBookmarkFolders(space = "star") {
  return request(`${baseUrl}/folders?space=${encodeURIComponent(space)}`);
}

export function createBookmarkFolder(data, space) {
  const payload = space ? { ...data, space } : (data.space ? data : { ...data, space: "star" });
  return request(`${baseUrl}/folders`, {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateBookmarkFolder(id, data, space) {
  const payload = space ? { ...data, space } : { ...data };
  return request(`${baseUrl}/folders/${id}`, {
    method: "PATCH",
    body: JSON.stringify(payload)
  });
}

export function deleteBookmarkFolder(id, space = "star") {
  return request(`${baseUrl}/folders/${id}?space=${encodeURIComponent(space)}`, { method: "DELETE" });
}

export function getBookmarkItems(filters = {}, space = "star") {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") query.set(key, value);
  });
  query.set("space", filters.space || space);
  return request(`${baseUrl}/items?${query.toString()}`);
}

export function detectBookmarkMetadata(sourceUrl) {
  return request(`${baseUrl}/metadata`, {
    method: "POST",
    body: JSON.stringify({ sourceUrl })
  });
}

export function createBookmarkItem(data, space) {
  const payload = space ? { ...data, space } : { ...data };
  return request(`${baseUrl}/items`, {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateBookmarkItem(id, data, space) {
  const payload = space ? { ...data, space } : { ...data };
  return request(`${baseUrl}/items/${id}`, {
    method: "PATCH",
    body: JSON.stringify(payload)
  });
}

export function deleteBookmarkItem(id, space = "star") {
  return request(`${baseUrl}/items/${id}?space=${encodeURIComponent(space)}`, { method: "DELETE" });
}

export function getRandomBookmark(space = "cookie", folderId = "") {
  const query = new URLSearchParams({ space });
  if (folderId) {
    query.set("folderId", folderId);
    query.set("folderIds", folderId);
  }
  return request(`${baseUrl}/random?${query.toString()}`);
}

export function getBookmarkTags(space = "star") {
  return request(`${baseUrl}/tags?space=${encodeURIComponent(space)}`);
}
