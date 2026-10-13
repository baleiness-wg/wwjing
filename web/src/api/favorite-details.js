import { request } from "./http";

export function getFavoriteDetails(folderId) {
  const query = folderId ? `?folderId=${encodeURIComponent(folderId)}` : "";
  return request(`/api/favorite-details${query}`);
}

export function createFavoriteDetail(payload) {
  return request("/api/favorite-details", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
