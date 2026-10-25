---
title: The Markdown Editor
description: What the note editor supports, starting with list markers
status: living
updated: 2026-10-25
---

# The Markdown editor

The editor is a plain textarea with Markdown behaviors built on top — list continuation on Enter, Tab/Shift+Tab inside lists, and a preview that renders CommonMark. This page records the parts of that behavior users can rely on, so nobody has to discover them by trial and error.

## Lists

List markers are CommonMark's, and only CommonMark's:

| Kind | Markers |
| --- | --- |
| Bullet | `-`, `*`, `+` |
| Ordered | An ASCII number followed by `.` or `)` — `1.`, `1)` |

Adding `[ ]` or `[x]` after a marker makes the item a task: `- [ ]`, `- [x]`, `1. [ ]`. Pressing Enter on a task item continues it with an empty `[ ]`. (TODO notes are still the better home for a checklist you manage over time; tasks inside a Markdown note are for checklists that live in the prose.)

Japanese bullets are **not** converted into lists, by design. A line starting with `・`, `ー` or `－`, or an ordered item written with full-width numbers such as `１．`, is ordinary text: the editor does not continue it as a list, and the preview renders it as a paragraph, not a list item. This is CommonMark behavior — those characters are not list markers there — and there is no plan to special-case them. Rewrite `・ a` as `- a` if you want a list.

One gap nuance: after a valid marker, the editor's list behaviors also accept a full-width space (or a no-break space) where CommonMark expects a regular space, and rewrite it to a regular space when the list continues. Indentation at the start of a line, though, must be regular spaces or tabs — a line indented with a full-width space is not a list item.
