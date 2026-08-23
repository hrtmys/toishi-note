import { application } from "./application"

import AutosaveController from "./autosave_controller"
application.register("autosave", AutosaveController)

import EditorController from "./editor_controller"
application.register("editor", EditorController)

import CompareController from "./compare_controller"
application.register("compare", CompareController)

import CompareLauncherController from "./compare_launcher_controller"
application.register("compare-launcher", CompareLauncherController)

import MarkdownController from "./markdown_controller"
application.register("markdown", MarkdownController)

import PromptFormController from "./prompt_form_controller"
application.register("prompt-form", PromptFormController)

import ResetFormController from "./reset_form_controller"
application.register("reset-form", ResetFormController)

import ScrollController from "./scroll_controller"
application.register("scroll", ScrollController)

import NavigationController from "./navigation_controller"
application.register("navigation", NavigationController)

import TextFormatController from "./text_format_controller"
application.register("text-format", TextFormatController)

import WordCopyController from "./word_copy_controller"
application.register("word-copy", WordCopyController)

import BulkTodoImportController from "./bulk_todo_import_controller"
application.register("bulk-todo-import", BulkTodoImportController)

import ToastController from "./toast_controller"
application.register("toast", ToastController)

import SettingsController from "./settings_controller"
application.register("settings", SettingsController)

import EditorFabController from "./editor_fab_controller"
application.register("editor-fab", EditorFabController)

import NoteSortController from "./note_sort_controller"
application.register("note-sort", NoteSortController)

import ImageUploadController from "./image_upload_controller"
application.register("image-upload", ImageUploadController)

import WordPasteController from "./word_paste_controller"
application.register("word-paste", WordPasteController)

import TablePasteLauncherController from "./table_paste_launcher_controller"
application.register("table-paste-launcher", TablePasteLauncherController)

import ScrapItemController from "./scrap_item_controller"
application.register("scrap-item", ScrapItemController)

import ScrapCopyAllController from "./scrap_copy_all_controller"
application.register("scrap-copy-all", ScrapCopyAllController)

import OffcanvasController from "./offcanvas_controller"
application.register("offcanvas", OffcanvasController)

import OrganizeController from "./organize_controller"
application.register("organize", OrganizeController)

import SetupAuthMethodController from "./setup_auth_method_controller"
application.register("setup-auth-method", SetupAuthMethodController)

import SelectOnClickController from "./select_on_click_controller"
application.register("select-on-click", SelectOnClickController)

import SubmitOnChangeController from "./submit_on_change_controller"
application.register("submit-on-change", SubmitOnChangeController)

import NoteConflictController from "./note_conflict_controller"
application.register("note-conflict", NoteConflictController)

import ListContinuationController from "./list_continuation_controller"
application.register("list-continuation", ListContinuationController)

import PaletteController from "./palette_controller"
application.register("palette", PaletteController)
