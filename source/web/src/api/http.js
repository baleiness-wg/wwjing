export async function request(url, options = {}) {
  const headers = new Headers(options.headers);
  const token = localStorage.getItem("wwjing_token");

  if (token) headers.set("Authorization", token);
  if (options.body && !(options.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(url, { ...options, headers });

  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));

    if (response.status === 401 && !window.location.pathname.endsWith("/login")) {
      localStorage.removeItem("wwjing_token");
      localStorage.removeItem("wwjing_user");
      const loginPath = `${import.meta.env.BASE_URL}login`.replace(/\/+/g, "/");
      if (window.location.pathname !== loginPath) window.location.replace(loginPath);
    }

    const details = payload.error || payload;
    const error = new Error(details.message || "请求失败");
    error.status = response.status;
    error.code = details.code;
    Object.assign(error, details);
    throw error;
  }

  if (response.status === 204) return null;
  return response.json();
}
