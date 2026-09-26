// Cleans a stored/candidate "last note location" for the navigation
// controller. Only a bare root ("/") on the same origin is worth
// restoring; mode params (organize/todos/view) shouldn't be replayed.
export function rememberablePath(href, origin) {
  let url
  try {
    url = new URL(href)
  } catch (_) {
    return null
  }

  if (url.origin !== origin || url.pathname !== "/") return null

  url.searchParams.delete("organize")
  url.searchParams.delete("todos")
  url.searchParams.delete("view")

  return url.href
}
