import { request } from "./http";

export function getFavoriteDetails() {
  return request("/api/favorite-details");
}

export function createFavoriteDetail(payload) {
  return request("/api/favorite-details", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
