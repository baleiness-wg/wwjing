import { request } from "./http.js";

const baseUrl = "/api/bookmarks";

export function getBookmarkFolders() {
  return request(`${baseUrl}/folders`);
}

export function createBookmarkFolder(data) {
  return request(`${baseUrl}/folders`, {
    method: "POST",
    body: JSON.stringify(data)
  });
}

export function updateBookmarkFolder(id, data) {
  return request(`${baseUrl}/folders/${id}`, {
    method: "PATCH",
    body: JSON.stringify(data)
  });
}

export function deleteBookmarkFolder(id) {
  return request(`${baseUrl}/folders/${id}`, { method: "DELETE" });
}

export function getBookmarkItems(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") query.set(key, value);
  });
  return request(`${baseUrl}/items?${query.toString()}`);
}

export function detectBookmarkMetadata(sourceUrl) {
  return request(`${baseUrl}/metadata`, {
    method: "POST",
    body: JSON.stringify({ sourceUrl })
  });
}

export function createBookmarkItem(data) {
  return request(`${baseUrl}/items`, {
    method: "POST",
    body: JSON.stringify(data)
  });
}

export function updateBookmarkItem(id, data) {
  return request(`${baseUrl}/items/${id}`, {
    method: "PATCH",
    body: JSON.stringify(data)
  });
}

export function deleteBookmarkItem(id) {
  return request(`${baseUrl}/items/${id}`, { method: "DELETE" });
}
