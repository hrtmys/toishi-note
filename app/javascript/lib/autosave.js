// A 409 means another device saved first; any other non-2xx is a failure
// the user must hear about, never a silent success.
export function saveOutcome(status) {
  if (status === 409) return "conflict"
  if (status >= 200 && status <= 299) return "saved"
  return "failed"
}
