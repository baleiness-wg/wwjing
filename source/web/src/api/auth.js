import { request } from "./http";

export function register(payload) {
  return request("/api/auth/register", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function login(payload) {
  return request("/api/auth/login", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function changePassword(payload) {
  return request("/api/auth/change-password", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function getProfile() {
  return request("/api/auth/user-profile");
}

export function updateProfile(payload) {
  return request("/api/auth/user-profile", {
    method: "PATCH",
    body: JSON.stringify(payload)
  });
}
