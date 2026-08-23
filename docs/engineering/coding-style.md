---
title: Coding Style
description: Ruby/Rails conventions for this repository
status: living
updated: 2026-08-09
---

# Coding style

Ride Rails' conventions, don't fight them. Anything a linter can settle mechanically is settled by the linter — this document only covers what Rubocop can't decide for you.

## Style is Rubocop's job

`.rubocop.yml` inherits [`rubocop-rails-omakase`](https://github.com/rails/rubocop-rails-omakase). Indentation, quoting, spacing — all settled automatically. Run `bin/rubocop -A` before opening a PR and don't relitigate formatting in review.

## Ride the Rails way

- **Convention over configuration.** Keep [`config/routes.rb`](../../config/routes.rb) RESTful with `resources` blocks. Don't invent a custom routing DSL.
- **Fat model, skinny controller.** Business logic lives in the model. When a model gets too fat, reach for `app/models/concerns` or a plain Ruby object (PORO) before reaching for a Service Object layer — don't add that layer until something genuinely spans multiple models.
- **Pick bang vs. non-bang deliberately, not out of habit.** For simple, low-risk mutations where invalid input is effectively a client/programmer error (renaming a notebook/folder — just a presence-validated `:name`), the bang variants (`create!` / `update!` / `destroy!`) are fine: a failure is rare enough that surfacing it as a loud error is an acceptable trade-off for staying terse. For actions handling content users type and expect inline feedback on (todo/scrap/note text, anything rendered back into a turbo_stream), use `build`/`save`/`update` with an explicit `if/else` that renders `head :unprocessable_entity` on failure — don't let user-typed content crash the request.
- **Don't rely on `created_at`/`updated_at` for domain meaning they weren't designed to carry.** If something needs an explicit point in time or an explicit order, model it with its own column. Example already fixed here: `todo_items`/`scrap_items` have a `position` column for display order — [`app/models/concerns/positioned.rb`](../../app/models/concerns/positioned.rb) assigns it on create, and `Note` orders the associations by it, instead of the earlier code ordering by `created_at`.
- **Notebooks (and everything under them) are private to whoever created them — always look them up through `Current.user`, never a bare `Model.find`.** `Current.user.notebooks.find(...)`, `Current.user.notes.find(...)`, `Current.user.folders.find(...)` — a bare `Notebook.find(params[:id])` (or `Note.find`, etc.) reads across every account's data, which is exactly the bug this pattern exists to rule out by construction. `NotebooksController`/`FoldersController`/`NotesController`/`TodoItemsController`/`ScrapItemsController` are the reference examples; `test/controllers/notebook_privacy_test.rb` is what regresses if this slips.

## Comments

- **Write comments in English**, same reasoning as [docs being in English](../README.md): code is read by anyone who ends up contributing, regardless of what language the surrounding conversation happened in.
- **Don't narrate history in comments.** No `# added: ...` / `# changed: ...` style comments — that's git history's job, and a comment like that goes stale (and starts lying) the moment it's no longer recent. Only comment on *why* the code is the way it is.
  - Bad: `# changed from nullify to destroy`
  - Good: `# Deleting a folder cascades to its notes, so none are orphaned`
- **Don't mark block boundaries with comments.** Something like `# end of this section` is redundant — Ruby's `end` and method boundaries already make that clear.

## Tests

- Use [Minitest](https://guides.rubyonrails.org/testing.html) (the Rails default). Don't introduce RSpec. Follow the existing `test/` layout (`test/models`, `test/controllers`, `test/system`).

## Views

- Keep ERB free of complex branching. Once a condition spans more than two lines, move it into a helper or a model method.
- Pass values to partials explicitly via `locals:` (e.g. `render partial: "todo_items/progress", locals: { note: @current_note }`). Don't have a partial implicitly reach for an instance variable.

## Naming & file layout

- Standard Rails naming: snake_case filenames, CamelCase class names, plural table names. This is already consistent in the codebase — keep it that way.

## Strings & i18n

- **New user-facing copy goes into `config/locales` in both languages, in the same change that introduces it.** This used to say "not a retrofit task right now" — that was written before the app was fully translated. It is now, and `test/i18n_completeness_test.rb` fails on any literal `t("...")` key missing from either locale, so hardcoded copy is a defect rather than a deferred chore.
- Strings a Stimulus controller needs at runtime (a toast, a client-side validation message) belong in the `js` subtree, which ships to the browser in a meta tag on every page — keep it small, and keep everything else server-rendered.

## Extracting reusable pieces

When a piece of logic doesn't actually depend on the rest of this app — a clipboard conversion, a citation-metadata lookup, a paste handler — consider shipping it as its own npm package or gem instead of burying it in `app/javascript/lib` or `app/models/concerns` forever. [`word_clipboard.js`](../../app/javascript/lib/word_clipboard.js) is the current example of something shaped like this. Smaller, independently useful packages are easier for outside contributors to pick up than one large app, and each one is a separate surface for the project to be discovered through.
