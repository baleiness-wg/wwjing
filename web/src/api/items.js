import { request } from "./http";

export function getItems() {
  return request("/api/items");
}

export function createItem(payload) {
  return request("/api/items", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
