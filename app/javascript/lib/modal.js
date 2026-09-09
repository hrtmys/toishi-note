// Bootstrap's hide() is a silent no-op mid-show-transition, stranding the
// modal open. Queue the request instead: hide now if settled, else once
// the in-flight show completes. show()/hidden always clear the queue.
export function installModalHideQueue(element, getModal) {
  const state = { hideQueued: false }

  element.addEventListener("shown.bs.modal", () => {
    if (state.hideQueued) {
      state.hideQueued = false
      getModal().hide()
    }
  })
  element.addEventListener("hidden.bs.modal", () => {
    state.hideQueued = false
  })

  return state
}

export function showModal(state, modal) {
  state.hideQueued = false
  modal.show()
}

export function hideModal(state, modal) {
  state.hideQueued = true
  modal.hide()
}
