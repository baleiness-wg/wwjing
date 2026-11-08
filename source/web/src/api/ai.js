import { request } from "./http.js";

export function chatWithDirectory(context, message, history = []) {
  return request("/api/ai/chat", {
    method: "POST",
    body: JSON.stringify({ context, message, history })
  });
}
