import { Controller } from "@hotwired/stimulus"

// Bridges a server-rendered flash[:toast] (see application.html.erb) into
// the app-wide toast (app/javascript/controllers/toast_controller.js) on
// the next page load, so redirect-driven controller actions (notebook/
// folder/note create, rename, delete) get the same visible confirmation
// as the JS-driven actions that already dispatch toast:show directly.
export default class extends Controller {
  static values = { message: String }

  connect() {
    window.dispatchEvent(new CustomEvent("toast:show", { detail: { message: this.messageValue } }))
  }
}
