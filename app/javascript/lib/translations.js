// Client-side counterpart to Rails' t() — for strings a Stimulus
// controller needs at runtime. Backed by the "js" locale subtree,
// serialized once per page load into <meta name="translations">.
const translations = JSON.parse(document.querySelector('meta[name="translations"]')?.content || "{}")

// Dotted path into the object above, with Rails-style %{name}
// interpolation. Falls back to the path itself if a key is missing,
// rather than throwing mid-handler.
export function t(path, replacements = {}) {
  const template = path.split(".").reduce((value, key) => value?.[key], translations) ?? path

  return Object.entries(replacements).reduce(
    (result, [key, value]) => result.replaceAll(`%{${key}}`, value),
    template
  )
}
