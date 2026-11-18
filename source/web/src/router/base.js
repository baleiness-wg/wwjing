const applicationRoutes = new Set(["office", "transfer", "tools", "login"]);

export function getApplicationBase(pathname = window.location.pathname) {
  const firstSegment = pathname.split("/").filter(Boolean)[0];
  return firstSegment && !applicationRoutes.has(firstSegment) ? `/${firstSegment}/` : "/";
}
