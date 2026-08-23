# On a fresh install, db:prepare runs this before Setup, so there's no
# one to own demo data yet. Skip rather than fail; re-run after Setup.
owner = User.member.order(:registered_at).first

unless owner
  puts "No member account exists yet — skipping the welcome notebook."
  puts "Visit the app, finish Setup, then run `bin/rails db:seed` again if you want it."
  return
end

# Resets every account's notebooks, not just `owner`'s — meant for a
# throwaway dev database, not one with real data you'd want to keep.
TodoItem.destroy_all
ScrapItem.destroy_all
Note.destroy_all
Folder.destroy_all
Notebook.destroy_all

# A first-run welcome notebook, what a new account sees instead of an
# empty sidebar. Locale is the owner's preference, since there's no
# request to read Accept-Language from here.
locale = (owner.locale || I18n.default_locale.to_s).to_sym

available_content = {
  en: {
    notebook: "Welcome to Toishi Note",
    folder: "Getting Started",
    guide_title: "Start here",
    guide: <<~MD,
      # Toishi Note in three note types

      This notebook is the whole tutorial — delete it once you don't need it.

      ## Three note types, one purpose each

      - **Markdown** (this note) — for anything you'd normally write in prose:
        study notes, a proofread AI draft, documentation.
      - **TODO** — a real checklist, not a bullet pretending to be one. See
        *Sample tasks* in this folder.
      - **Scrap** — a fragment stream for catching AI output as it comes,
        before it's polished into a real note. See *Scrap examples*.

      ## This editor renders as you type

      Code:

      ```ruby
      Note.where(note_type: "md").count
      ```

      Math (KaTeX):

      $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

      Diagrams (Mermaid):

      ```mermaid
      flowchart TD
        A[Write] --> B[Autosave]
        B --> C[Synced everywhere you sign in]
      ```

      ## Worth turning on in Settings (the gear icon, top left)

      Every feature below starts off — turn on only what you'll actually use.

      - **AI formatting tools** — a floating button with cleanup helpers for
        text pasted from an AI chat (full-width→half-width, stray brackets,
        that kind of thing).
      - **Compare** — a before/after diff view, useful for checking exactly
        what an AI rewrite changed.
      - **Word/Excel paste conversion** — pasting from Word auto-converts to
        Markdown; an Excel/Sheets selection pastes as an image by default,
        with a one-click "Convert to Markdown" when you actually want the
        table.
    MD
    todo_title: "Sample tasks",
    todo_items: [
      { text: "Read this note", checked: true },
      { text: "Try the Markdown/Split/Preview buttons above the editor", checked: false },
      { text: "Add a due date to a task (the calendar icon next to Add)", checked: false }
    ],
    scrap_title: "Scrap examples",
    scrap_items: [
      "Paste something straight from an AI chat here — Scrap is built for catching it before it's polished.",
      "Once a fragment is worth keeping, use \"Promote to note\" to turn it into a real Markdown note."
    ]
  },
  ja: {
    notebook: "Toishi Noteへようこそ",
    folder: "はじめに",
    guide_title: "まずはここから",
    guide: <<~MD,
      # 3種類のノートタイプ

      このノートブックがチュートリアルです。不要になったら削除してください。

      ## 3つのノートタイプ、それぞれの役割

      - **Markdown**（このノート）— 学習メモ、AI下書きの推敲、ドキュメントなど、
        文章として書くもの全般に。
      - **TODO** — 見せかけの箇条書きではない、実際に完了を管理できるチェックリスト。
        このフォルダ内の「サンプルタスク」を参照。
      - **Scrap** — 磨き上げる前のAI出力などを、そのまま書き留めておく場所。
        「Scrapの例」を参照。

      ## 入力しながらその場でレンダリングされます

      コード:

      ```ruby
      Note.where(note_type: "md").count
      ```

      数式（KaTeX）:

      $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

      ダイアグラム（Mermaid）:

      ```mermaid
      flowchart TD
        A[書く] --> B[自動保存]
        B --> C[どこからサインインしても同期]
      ```

      ## 設定（左上の歯車アイコン）で有効にする価値があるもの

      以下はすべて初期状態でオフです。実際に使うものだけ有効にしてください。

      - **AI整形ツール** — AIチャットからの貼り付けテキストを整えるフローティング
        ボタン（全角/半角統一、不要な括弧の除去など）。
      - **比較（Compare）** — AIによる書き換えで実際に何が変わったかを確認できる、
        Before/After形式の差分表示。
      - **Word/Excel貼り付け変換** — Wordからの貼り付けは自動でMarkdown化。
        Excel/Sheetsの範囲貼り付けは既定で画像になり、必要な時だけワンクリックで
        「Markdownに変換」できます。
    MD
    todo_title: "サンプルタスク",
    todo_items: [
      { text: "このノートを読む", checked: true },
      { text: "エディタ上部のMarkdown/分割/プレビューボタンを試す", checked: false },
      { text: "タスクに期限を設定する（Add横のカレンダーアイコン）", checked: false }
    ],
    scrap_title: "Scrapの例",
    scrap_items: [
      "AIチャットの出力をそのままここに貼り付けてみてください。磨き上げる前の下書き置き場です。",
      "残しておきたい断片は「ノートに昇格」で独立したMarkdownノートに変換できます。"
    ]
  }
}

# Falls back to English for any locale other than the two above — not
# reachable today, but a third locale added later should degrade
# gracefully rather than raise on a missing key.
content = available_content.fetch(locale, available_content.fetch(:en))

notebook = owner.notebooks.create!(name: content[:notebook])
folder = notebook.folders.create!(name: content[:folder])

folder.notes.create!(
  notebook: notebook,
  title: content[:guide_title],
  note_type: "md",
  content: content[:guide]
)

todo_note = folder.notes.create!(notebook: notebook, title: content[:todo_title], note_type: "todo")
content[:todo_items].each do |item|
  todo_note.todo_items.create!(content: item[:text], is_checked: item[:checked])
end

scrap_note = folder.notes.create!(notebook: notebook, title: content[:scrap_title], note_type: "scrap")
content[:scrap_items].each { |text| scrap_note.scrap_items.create!(content: text) }

puts "Welcome notebook created (#{locale})."
