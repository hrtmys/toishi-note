# 監査レポート (repo-audit)

対象: https://github.com/hrtmys/toishi-note / master 最新 (2026-09-06 時点)
観点: general / rails-omakase / ux-ui / css(独自) / matz-dhh-style / test(独自)。
方針: 指摘を優先し、既存ロジックの書き換えは行わない。コード変更・ブランチ作成なし。

## general

### 確証度の高い所見

#### G-1: 信頼ヘッダの直接到達でなりすまし可能 [High]
- **ファイル**: `app/models/trusted_header_login.rb:21-33`
- **症状**: `TRUSTED_HEADER_AUTH_HEADER` で指定されたヘッダ値を無条件に本人確認として扱う。プロキシでの strip/上書きが唯一の境界で、アプリ側に送信元 IP 制限等の二重防御がない。
- **再現条件**: 上記 ENV 設定時に、プロキシを経由せずアプリへ直接 HTTP リクエストし、任意のメールアドレスを該当ヘッダに付与する。
- **影響**: フルアカウント乗っ取り + 勝手なアカウント自動作成。設計上「プロキシが strip する」前提(コード内コメントにも明記)のため、デプロイ構成の問題でもある。`TrustedHeaderLogin` 有効時はアプリを外部に直接公開しない運用の明文化、または `TRUSTED_PROXY_IPS` 的な送信元制限の追加を推奨。

#### G-2: `note_type` 不正値で 500 [Medium]
- **ファイル**: `app/controllers/notes_controller.rb:3-11`, `app/models/note.rb:14`
- **症状**: `params.permit(:note_type)[:note_type]` を無検証で `Note.create!` に渡す。`enum` が不正値を `ArgumentError` で拒むため 500 になる。
- **再現条件**: `POST /notes` に `folder_id=<自身の物>, note_type=evil` を送る。
- **影響**: 500 (可用性)。ホワイトリスト検証で 422 にすべき入力バリデーション漏れ。

#### G-3: `Positioned` 生成時に position 重複 [Medium]
- **ファイル**: `app/models/concerns/positioned.rb:17-24`
- **症状**: `before_create` で `(siblings.maximum(:position) || 0) + 1`。ロックも一意制約もない (`db/schema.rb` に `[parent_id, position]` の unique index なし)。
- **再現条件**: 同一 note/notebook に対し todo/folder 等の `POST` を 2 並列で送る。
- **影響**: 同一 position 重複。表示順が不定になる。「複数人が同時に同じ手順」用途に直撃。

#### G-4: `Positioned.reposition!` が非トランザクション + TOCTOU [Medium]
- **ファイル**: `app/models/concerns/positioned.rb:30-37`
- **症状**: `ids.sort == relation.ids.sort` の検証と `update_column` ループの間にロック/トランザクションがない。失敗時・並行時に部分書き込みになる。
- **再現条件**: 端末 A が reorder 中に、端末 B が同スコープで folder/notebook を create/destroy する。またはループ途中で 1 件が消える。
- **影響**: 順序の半更新・不整合。`update_column` のためコールバック/バリデーションも素通り。

#### G-5: scrap `promote` が非アトミックで二重作成 [Medium]
- **ファイル**: `app/controllers/scrap_items_controller.rb:31-44`
- **症状**: `folder.notes.create!` と `@item.destroy!` がトランザクション/行ロックなし。
- **再現条件**: 同一 scrap item の `POST promote` をダブルクリック/2 タブ同時送する。
- **影響**: 同一内容の md note が 2 件作られる (重複データ)。片方の `destroy` が空振りしても重複側は残る。

#### G-6: `Folder#move_to!` と並行 note 作成で `notebook_id` 不整合 [Medium]
- **ファイル**: `app/models/folder.rb:16-23`
- **症状**: `transaction { update!(notebook:) + notes.update_all(notebook_id:) }` は行ロックなし。`update_all` と並行 `NotesController#create` が競合する。不変条件 `note.notebook == folder.notebook` はアプリ層のみで DB 保証なし。
- **再現条件**: 端末 A が folder を別 notebook へ `move` する最中に、端末 B が同 folder に note を作成する。
- **影響**: 新 note が旧 `notebook_id` のまま残り、サイドバー/エクスポートの所属がずれる。

#### G-7: 初期セットアップの TOCTOU で複数 first-user [Medium]
- **ファイル**: `app/controllers/setup_controller.rb:23-26,28-60`
- **症状**: `ensure_no_users_yet (User.exists?)` と `User.new.save / User.create!` の間に排他がない。DB 層に「ユーザは 1 件まで」のガードなし。
- **再現条件**: 空 DB へ `POST /setup` を 2 並列送する。
- **影響**: 「最初の 1 件」不変条件が崩れ、member/admin 混在の想定外初期状態になる。発生頻度は低いが影響大。

#### G-8: `TrustedHeaderLogin` 初回並行で 500 [Medium]
- **ファイル**: `app/models/trusted_header_login.rb:30`
- **症状**: `User.find_or_create_by!` は find→create の間に競合すると敗者が unique 制約 (`index_users_on_email_address`) で `RecordNotUnique` → 500。
- **再現条件**: 未登録アドレスで信頼ヘッダログインを 2 並列送する。
- **影響**: 片系 500。

#### G-9: 期限切れ reset token が 404 になる [Medium]
- **ファイル**: `app/controllers/passwords_controller.rb:30-34`
- **症状**: `set_user_by_token` が `InvalidSignature` のみ rescue。期限切れ(署名検証は通るがレコード解決が nil → `find_by_...!` が `RecordNotFound`)は 404 になる。
- **再現条件**: 発行から 24h 超のリンクで `GET /passwords/:token/edit` を開く。
- **影響**: 本来の「無効・期限切れ」誘導 (`passwords.flash.invalid_or_expired`) にならず 404。期限切れは通常運用で頻出。

#### G-10: 画像アップロードの実体検証・上限なし [Medium]
- **ファイル**: `app/controllers/note_images_controller.rb:6-11`, `app/models/note.rb:62-72`
- **症状**: `content_type.start_with?("image/")` の申告値のみ検査。実体検証・サイズ上限なし。非画像を `image/*` と偽ると `ImageProcessing::Vips` が例外 → 500。巨大ファイルもそのまま `attach`。
- **再現条件**: テキストファイルを `Content-Type: image/png` で `POST /notes/:id/images` する。または数十 MB 画像を投げる。
- **影響**: 500 / リソース枯渇 (可用性)。当該 note 所有者スコープ済みのため他ユーザへの波及は DoS のみ。

#### G-11: `bulk_create` が件数無制限 [Medium]
- **ファイル**: `app/controllers/todo_items_controller.rb:47-54,66-87`
- **症状**: `JSON.parse(raw.to_s)` → `filter_map → select(&:save)` を上限・トランザクションなしで N 件 INSERT。`content` に長さバリデーションなし。
- **再現条件**: `POST bulk_create` に巨大配列 (例: 数万件) を送る。
- **影響**: DB 膨張・リクエストタイムアウト。認証済み自己アカウント発でも Puma/DB 共有のため全員に DoS 波及しうる。

#### G-12: タイトル空消しで自動命名が永久停止 [Low]
- **ファイル**: `app/controllers/notes_controller.rb:22`, `app/models/note.rb:86-101`
- **症状**: `title` キー存在で一律 `title_customized: true` を付与。空文字でも同様。
- **再現条件**: `PATCH /notes/:id {note:{title:""}}` 後、`PATCH {note:{content:"新しい一行"}}` を送る。題が内容から再生成されない。
- **影響**: プレースホルダ題で固着。データ破壊ではない。

#### G-13: Zip エントリに `..` が残る [Low]
- **ファイル**: `app/models/concerns/exportable.rb:9-12`, `app/models/notebook_exporter.rb:34-46`
- **症状**: `export_basename` は `[/\\:*?"<>|]` のみ `_` 化。`..` を除去しない。folder/note 名 `..` でエントリ `../*.md` になりうる。
- **再現条件**: folder 名を `..` にして `GET /notebooks/:id/export`。
- **影響**: 素朴な unzip で親ディレクトリ書込み (traversal)。自己エクスポートの自己被害に限定。

#### G-14: 削除済み `last_notebook/folder` が残る [Low]
- **ファイル**: `app/controllers/home_controller.rb:18-26,54-58`, `db/schema.rb:113-114`
- **症状**: `last_notebook_id/last_folder_id` に FK なし。notebook/folder 削除時にクリアもしない。次回は `find_by` が nil → 先頭に fallback するため致命的ではない。
- **再現条件**: 最後に見ていた notebook を削除して `/` を開き直す。
- **影響**: 残骸 ID が残るのみ。動作は fallback で救済。

### 要確認 (確証度低)
- Y-1 `lock_version` 省略で楽観ロック素通り: Organize 改名フォームは `lock_version` なしで正常保存することがテストで固定。並行 Organize 改名同士は 409 なく last-write-wins。意図的トレードオフか要確認。[Low-Medium]
- Y-2 bulk が `due_date` を捨てる: 単発 `create` は `due_date` を受けるが bulk は無視。仕様か欠落か要確認。
- Y-3 todo 更新は `is_checked` のみ: `content/due_date` 更新は黙って無視 (成功応答)。不変設計か要確認。
- Y-4 ヘッダメールの正規化ずれ: 生値で `find_or_create_by!` するが `User` は `normalizes :email_address`。`Foo@X.com` と `foo@x.com` で find 失敗→ create で衝突しうる。実害の有無要確認。[Low]
- Y-5 reset `update` に rate_limit なし: `create` のみ制限。トークン推測はエントロピー的に現実的でないため問題ない可能性が高いが要確認。[Low]
- Y-6 最後の admin/owner 削除可: `Admin::UsersController` は自己削除のみ阻止。last-admin 削除で管理者不在、owner 削除で solo-pin 喪失。運用想定か要確認。[Low]

### 問題なしと確認した点
- `Current.user` スコープ漏れなし (素の `Note.find/Folder.find` なし。`Admin::UsersController` の `User.find` は `require_admin` 配下の意図的管理操作)。
- mass-assignment: `notebook/folder/note/todo/scrap/settings` の permit は最小。`move` 系が宛先をサーバ側導出している点は良好。
- XSS: `raw/html_safe` なし。markdown描画は `DOMPurify.sanitize` 必須。bulk preview は `textContent` のみ。

## rails-omakase

対象範囲: `app/models`, `app/controllers`, `app/jobs`, `app/views`, `config/routes`, `Gemfile` 中心。外部サイト `https://rails-omakase.me` にはアクセスせず、リポジトリ内の実装のみで判断。

### 1. fat model / skinny controller
全体としては skinny controller を維持しており良好。
- 1-1 [Medium] `app/controllers/todo_items_controller.rb:66-87` (`todo_items_from_bulk_json`, `build_bulk_todo_item`): JSONパース・バリデーション・`build` という業務ロジックが controller の private メソッドに約20行常駐。`Note`/`TodoItem` 側に寄せられる処理（例: `note.build_bulk_todo_items(raw)`）。controller が fat 化の起点。テストが controller 経由になり再利用・単体検証しにくい。現状は1箇所のみの使用なので実害小。
- 1-2 [Low] `app/controllers/palette_controller.rb:19-34` (`search`): 前方一致優先＋`last_viewed_at` 降順というランキング業務ロジックが controller にある。`Note` の scope / クラスメソッドに置ける。検索仕様変更時に controller を触る構造。
- 1-3 [Low] `app/controllers/notes_controller.rb:30-48`: turbo-stream の組み立て分岐が controller 内で手組み。素の `update.turbo_stream.erb` テンプレートに寄せられる形。規模が小さく意図も明確で omakase 逸脱とまでは言えない。

### 2. 素のRails機能の車輪の再発明・余計なgem置き換え
所見なし（良好）。`Gemfile:4-41` は rails 8.1 / propshaft / turbo / stimulus / solid_* / bcrypt / image_processing のみ。devise・認可gem・ページネーション・検索gemなし。`has_secure_password reset_token:`、`normalizes`、`enum`、`allow_browser versions: :modern`、`rate_limit`、`params.expect`、`deliver_later` 等の標準機能を素直に使用。要確認・Low: `Gemfile:20` `jbuilder` は `**/*.jbuilder` が0件で未使用の可能性（削除判断前に initializer 等の確認が必要）。

### 3. Service Object / Form Object の「とりあえず」導入による複雑化
所見なし（良好）。`app/services`, `app/forms` は存在せず、`app/jobs` も `application_job.rb` のみ。`NotebookExporter` の PORO 化、`TrustedHeaderLogin` の `app/models` 直下配置はいずれも正当。

### 4. N+1 / eager loading
- 4-1 [Medium] `app/models/notebook_exporter.rb:15-21` + `app/models/note.rb:45-54`: `folders.includes(:notes)` までだが `note.to_markdown` が `todo_items` / `scrap_items` を遅延ロードし note数 × 最大2クエリの N+1。`includes(notes: [:todo_items, :scrap_items])` で解消可能。Export は全件走査のため線形に増加。
- 4-2 [Low] `app/models/note.rb:28-40` + `app/views/todo_items/_progress.html.erb:1-6`: `_progress` が COUNT 系を1レンダーあたり実質3回発行。ロード済み関連を `size` で使い回していない。単一note表示では実害小。
- 4-3 [Low] `app/controllers/home_controller.rb:23` / `app/views/home/_sidebar.html.erb:70`: `@folders` に `includes(:notebook)` がなく sidebar の rename/delete で folder件数分参照。件数が少なく実害はほぼない。
- 4-4 [Low] `app/models/concerns/positioned.rb:30-37`: `reposition!` が件数分 `update_column` ループ、bulk_create も1件ずつ INSERT。小規模配列想定のため見送り妥当。
- 良好点: `todos_controller.rb:8`, `home_controller.rb:48`, `palette_controller.rb:12` は `includes` 済み。

### 5. DRY原則（重点）
- 5-1 [Medium] `app/controllers/notes_controller.rb:6-11` vs `app/controllers/scrap_items_controller.rb:35-40`: `folder.notes.create!(...)` がほぼ同文で重複。`Note.create_in_folder!` 等の factory に寄せられる。
- 5-2 [Medium] `app/controllers/home_controller.rb:48` vs `app/controllers/palette_controller.rb:22`: MRU10件クエリの重複。両方に相互参照コメントがあり重複の自覚があるまま残置。`Note.recently_viewed` / `scope :recently_viewed` 1本化が素直。
- 5-3 [Low] `app/controllers/todo_items_controller.rb:10-13,22-25,38-41,50-53`: turbo_stream 組み立てが4アクションで重複。private helper 1本に寄せられる。
- 良好点: `Exportable` / `Positioned` / `organize_or` は切り出し済み。`Current.user.*.find` の繰り返しは認可スコープの意図的徹底。

総括: omakase 適合度は高い。残るは DRY の2件（5-1 note生成、5-2 MRU10件）と Export の N+1（4-1）が中心。

## ux-ui

「動くが使いにくい」「表示がおかしい」のみを扱う（コードレベルの実装バグは general の担当）。
1. [High] 自動保存の成功・失敗が画面に一切出ない: `app/javascript/controllers/autosave_controller.js:31-63`、`app/controllers/notes_controller.rb:54-56`。成功してもインジケータなし、失敗時も `catch` がなくトースト・バナーなし。不安定回線で編集中→保存失敗→見た目は入力できているまま→リロードで消える。同型で `scrap_item_controller.js:34-46`（source 保存失敗は console のみ）、`settings_controller.js:60-74`（設定トグル保存失敗も console のみ）。
2. [Medium] 画像アップロードのプレースホルダ／失敗文がそのまま本文として自動保存される: `app/javascript/controllers/image_upload_controller.js:32-59`。`![アップロード中...]()` 挿入直後に input イベント発火→500ms後の autosave が保存。失敗時は `![失敗...]()` が本文に残り autosave される。通知は console のみ。
3. [Medium] TODO・Scrap 追加フォームは送信中表示なし・二重送信可・失敗時に入力が消える: `app/views/notes/_todo_editor.html.erb:17-30`、`app/views/notes/_scrap_editor.html.erb:15-27`、`app/javascript/controllers/reset_form_controller.js:4-6`。追加ボタンに disabled 化・スピナーなし。`reset-form` は成功・失敗を区別せず reset するため422/通信失敗時にも入力が消える。失敗時の Turbo Stream は `head :unprocessable_entity` で画面通知なし。一方 `bulk_todo_import_controller.js:111-117` は成功時のみ閉じる正しい実装があり不整合。
4. [Medium] メイン画面にフラッシュ／トーストの成功・失敗表示がほぼない: `app/views/layouts/application.html.erb:40-47`、`app/controllers/notebooks_controller.rb:1-17`、`app/controllers/folders_controller.rb:1-19`、`app/controllers/notes_controller.rb:65-71`。レイアウトに flash 描画なし。Notebook/Folder/Note の作成・改名・削除・移動は無言。失敗系はエラーページに飛ぶだけ。一方、認証系だけは flash・errors を丁寧に表示しており画面差が大きい。
5. [Medium] `prompt()` による作成・改名はモバイルで使いにくい＋空キャンセルが無言: `app/views/home/_sidebar.html.erb:22-25,38-41,57-60,70-73`、`app/views/home/_organize_note.html.erb:11-16`、`app/javascript/controllers/prompt_form_controller.js:6-18`。ネイティブ prompt は小画面で見切れる・バリデーションなし。空/キャンセル時は無反応で「壊れている」と感じる。サーバー側エラーメッセージも画面に戻らない。
6. [High] hover しなければ見えない操作が多くタッチ端末では到達できない: `app/views/home/_sidebar.html.erb:34-45,70-77,140-149`、`app/views/home/index.html.erb:47,53`、`app/views/todo_items/_item.html.erb:20`、`app/views/scrap_items/_item.html.erb:14-16,22-29`。エクスポート・改名・削除・ピン留め・Scrap source 入力・昇格/削除が hover 時のみ表示。タッチには hover がないため基本操作が「ない」ように見える。
7. [Medium] アイコンのみボタンが多くタッチターゲットが小さく説明がない: `app/views/home/_sidebar.html.erb:91-118`。新規ノート3種・ソート切替 `U/C/A-Z` が title 属性のみの区別でタッチでは出ない。ボタン高さが44px目安を下回る。
8. [Low] ラベルのないフォーム要素が多数: `app/views/notes/_title_input.html.erb:1-10`、`app/views/notes/_todo_editor.html.erb:20,28`、`app/views/notes/_scrap_editor.html.erb:17-22`、`app/views/home/_palette.html.erb:12-15`、`app/views/todo_items/_bulk_import_modal.html.erb:15-19`。placeholder のみで label なし。TODO期日 date_field にもラベルなし。
9. [Medium] モバイルで Notebook/フォルダを選ぶとサイドバーが閉じずエディタが見えない: ノート行リンクだけ `click->offcanvas#close` が付き Notebook名・フォルダ名リンクには付いていない（`app/views/home/_sidebar.html.erb:31,67` vs `130-133`、`app/javascript/controllers/offcanvas_controller.js:21-25`）。狭い画面でタップすると offcanvas が開いたまま残り「画面が変わらない」と感じる。
10. [Medium] サイドバーが空のとき無言: `app/views/home/_sidebar.html.erb:27-82,90-102`。0件時 `<ul>` 空描画のみ。Organize 画面だけ empty メッセージあり（`_organize.html.erb:28`）。`current_folder` がないと新規ノートボタン群自体が非表示で代替案内なし。
11. [Medium] 競合バナーの「自分のを残す」は押した瞬間に消え結果不明／「再読み込み」は入力を捨てる確認なし: `app/views/home/index.html.erb:35-41`、`app/javascript/controllers/note_conflict_controller.js:28-41`。keepMine は再送信完了を待たず即 d-none。reload は確認なしで入力破棄。
12. [Low] パレット検索中に古い結果が出たまま／キーボード・読み上げ対応不足: `app/javascript/controllers/palette_controller.js:48-58,100-111`、`app/views/home/_palette_results.html.erb:1-24`。通信中スピナー・aria-busy なし。結果 li に role・フォーカスなし。
13. [Low] 設定トグルは保存中・失敗が分からない／言語切替は失敗してもリロード: `app/javascript/controllers/settings_controller.js:8-58`。失敗は console のみで表示と保存値がずれる。言語切替は finally でリロードし「変えたつもり」になる。
要確認: 競合バナーの d-none＋d-flex 併記（実機の CSS 適用順未確認、Low）。Ctrl+P の Print 乗っ取り（代替導線なしの可能性、Low）。`todos/index` の未翻訳ハードコード（Low）。All TODO 画面での進捗 Stream の欠番ターゲット挙動（Low）。

## css

前提: Bootstrap 5.3.8 のみ（Tailwind依存なし）。ブラウザ動的確認は未実施。
1. [Medium] `shrink-0` は未定義クラス（Tailwindの残骸）: `app/views/home/index.html.erb:13,35,37,43,46`、`app/views/home/_sidebar.html.erb:4,19,20,33,53,54,69,86,91,106,139,147`、`app/views/home/_organize.html.erb:7,13`、`app/views/home/_organize_notebook.html.erb:7`、`app/views/home/_organize_folder.html.erb:7`、`app/views/home/_organize_note.html.erb:7`、`app/views/notes/_md_editor.html.erb:2`、`app/views/notes/_todo_editor.html.erb:16`、`app/views/notes/_scrap_editor.html.erb:2,14`、`app/views/todos/index.html.erb:3`。Bootstrap 5 の正規クラスは `flex-shrink-0` でありリポジトリ内に `.shrink-0` 定義なし。約20箇所が no-op。狭幅・長タイトル時に保護したかった要素が縮む。
2. [Medium] 競合バナーの `d-none d-flex` 併用: `app/views/home/index.html.erb:35`、JS は `app/javascript/controllers/note_conflict_controller.js:22,36` で d-none のみ付け外し。同一要素に display:none と display:flex を常時付与しカスケード順依存。負け方次第で空の警告バーが常時レイアウトを占有。
3. [Medium] flex行内の `text-truncate` に `min-width: 0` がない: `app/views/home/_sidebar.html.erb:31,67,130-133`、`app/views/home/_organize_notebook.html.erb:5`、`app/views/home/_organize_folder.html.erb:5`、`app/views/home/_organize_note.html.erb:5`。flex既定 min-width:auto が縮小を拒み ellipsis が効かず長い名前が行の操作ボタンを押し出す。
4. [Low] エディタSplit表示が `w-50 × 2 + gap-2` で100%超: `app/views/notes/_md_editor.html.erb:15,16,30`、`app/javascript/controllers/editor_controller.js:45-50`。50%×2＋gap約8px超過でプレビュー右端のわずかな欠け。常時発生だが軽微。
5. [Medium] TODO行の本文spanに折返し／縮小ガードなし＋親は overflow-x-hidden で切り捨て: `app/views/todo_items/_item.html.erb:10`、`app/views/notes/_todo_editor.html.erb:10`。長い単語・URLでバッジ・削除ボタンを押し出し無言で切れる。Scrap側は text-break ありで対応漏れ。
6. [Low〜Medium] Markdownテーブル・diff出力に横溢れガードなし: `app/assets/stylesheets/_markdown_content.scss:6-10`、`app/views/notes/_md_editor.html.erb:30`、`app/assets/stylesheets/_text_diff.scss:4`、`app/views/shared/_compare_panel.html.erb:7-19,27`。table に overflow-x ガードなし。diff出力も word-break なし。
7. [Low] Scrapカード右上の絶対配置ボタンが本文と重なる: `app/views/scrap_items/_item.html.erb:1,22-29`。本文側に右パディングの逃げがなく hover 時に1行目末尾と重なる。
要確認（Low）: A. コードハイライトがダークテーマのまま明テーマ内に混在（`_github-dark.scss:19-22` vs `_markdown_content.scss:26-31`）。B. FABメニューが overflow-hidden の内側＋z-index:1030（`_editor_fab.scss`）。C. ページレベルの overflow:hidden 固定＋vh-100 依存（`application.bootstrap.scss:19-23`）の耐性観察。
問題なし: 閉じタグ漏れ・flex/grid破損なし。主要ERBに不整合なし。offcanvas ブレークポイント一致。shrink-0 以外の Tailwind 混入なし。

## matz-dhh-style

全体として Matz/DHH 流儀に非常によく沿っている。Service・Form・Repository 等の無駄な抽象化なし。PORO 2件はいずれも正当。Rails 8 の素直な書き方を選択。
所見（いずれも Low）:
- `app/models/note.rb:28-34`: `todo_items_total_count` / `todo_items_completed_count` が `todo_completion_percentage` のためだけの薄いラッパー。インライン化余地。
- `app/controllers/notes_controller.rb:15-63`: `update` が約40行。ストリーム組み立て部分の private 抽出余地。現状でも可読性に実害なし。
- `app/models/concerns/positioned.rb:21`: `public_send(parent_association).public_send(self.class.table_name)` とテーブル名文字列経由で sibling 取得。stringly-typed で親子関係変更時に壊れやすい。
### コメント規約
大半は模範的な なぜ コメント。以下は規約逸脱:
- `app/models/concerns/positioned.rb:1-10` [Low]: 冒頭コメント約10行ブロック（説明＋Usage例）。長さ基準（最大3行）を大幅超過。使用例は外部ドキュメント送りが原則。
- `app/controllers/home_controller.rb:13-17` [Low]: 解決順序コメント5行ブロック。内容は なぜ で正当だが2〜3行に圧縮可能。
- `app/models/user.rb:16-19` [Low]: 4行ブロック。内容は正当だが4行目は削って3行に収まる。
- `app/models/folder.rb:8` [Low]: `dependent: :destroy` の言い換え。なぜ なし。削除可能。
- `app/controllers/scrap_items_controller.rb:7` [Low]: `turbo_stream.append` の言い換え。削除可能。
- `app/controllers/notes_controller.rb:70` [Low]: 末尾コメントは redirect の言い換え。冗長。
- `app/helpers/application_helper.rb:20-22` [Low]: 末文が自己言及的メタ説明。削除で1〜2行になる。
要確認: `application_controller.rb:3` の allow_browser 補足は正当化可能。`notes_controller.rb:17,33-34` の注釈は なぜ として正当な可能性が高く維持でよい。Strong Parameters の expect/permit 混在はフォーム構造確認が必要なため断定しない。`application_controller.rb:47-58` の Accept-Language 手パースは Rails 本体に同等機能がなく正当。

## test

観点: custom「テストの妥当性」。DHH流（システムテスト最小限・下位レイヤー中心）を参照枠とする。
構造的事実: JSコントローラ用の単体テストランナが存在しない（31個の `app/javascript/controllers/*.js` に対しJSテスト基盤ゼロ。`docs/engineering/verification.md:40` が明言）。本来JS単体で済む振る舞いがすべてシステムテストに押し込められており、これがフレークと実行時間（`test:system` 約152秒）の根本原因。

### システムテストのフレーク性
- F1 [High] `test/system/organize_test.rb:224-243` (`drag` ヘルパ): 固定 `sleep 0.2` → `sleep 0.1×5` → `sleep 0.5` の3段タイミング依存。CI等の低速ランナーでドロップ位置判定がずれる／反映前にアサーションへ進む。順序・reparent系4テスト全てがこのヘルパ経由。
- F2 [High] `test/test_helper.rb:9-12` ＋ `.github/workflows/ci.yml:134-145`: `ENV["CI"]` 時のみ `minitest-retry` で最大2回リトライ、かつ逐次化。コメント自体が「ほぼ毎回無関係なテストがタイムアウト」と認めている。真の失敗も握りつぶされ、根本原因が放置・蓄積される。CI所要時間も最悪3倍化。
- F3 [High] `test/system/note_conflict_test.rb:3-98`: 2つの実Chromeウィンドウ＋500msデバウンス autosave の着弾をDBポーリングで待つ二重非同期。楽観ロックという重要回帰のテスト自体が最も重く最も不安定。
- F4 [High] `test/system/sidebar_scroll_test.rb:40-46,63-66`: 独自ポーリング＋ピクセル完全一致を要求。Chromeバージョン・フォント・DPRで1pxずれると失敗。スクロール位置という近似値を完全一致で縛る環境依存。
- F5 [Medium] `test/application_system_test_case.rb:13` (`Capybara.default_max_wait_time = 8`): スイート全体の待機上限引き上げで個々の遅延が見えなくなり、失敗時の待ちが膨張。タイムアウト値自体がフレークの包帯。
- F6 [Medium] `Timeout.timeout(...) { sleep 0.1 until <DBリロード条件> }` パターンの蔓延（7箇所以上: image_attachments、word_excel_paste、note_sort、i18n、scrap_improvements、editor_fab、note_conflict）。Capybaraのリトライ付きマッチャで書き換え可能な箇所が大半。`Timeout::Error` で文脈なく落ち、診断性が低い。
- F7 [Medium] hover依存の出現待ちコントロール（note_sort、scrap_improvements、export、sidebar_scroll の5ファイル）: headless Chrome の hover は位置・スクロール・ウィンドウサイズに敏感で `ElementNotInteractable` 系の間欠失敗。
- F8 [Medium] toast/`show`クラス・off-canvasアニメーションの検証（responsive_layouts、command_palette ほか）: toast自動消去との競合で成功・失敗どちらの誤判定も起こり得る。
- F9 [Medium] `test/application_system_test_case.rb:23-27` (`visit` オーバーライド＋`window.Stimulus` 待ち): バンドル実行開始≠個別コントローラ `connect()` 完了。paste/drop/IMEガード系の同期API直叩きテストの土台が粗い。
- F10 [Low] Selenium固有の癖のテスト側吸収（compare_view の `set("")` 回避策、word_excel_paste の合成イベント）: ドライバ更新で逆に壊れる結合。
- F11 [Low] `test/system/setup_flow_test.rb:5-7` (`User.destroy_all`＋`fixtures :all` 併用): 正確性は保たれるが往復が毎テスト発生し遅い。将来のスレッド並列化には危険。
- ドライバ設定自体（headless_chrome＋CI定番フラグ）は妥当。

### DHH流配分からの逸脱（システム→下位に落とせるもの)
原則「ブラウザでしか検証できないものだけ残す」。JS単体ランナ新設（`node:test` でも vitest でも可）とセットでの移行提案:
- D1 [Medium] `export_test.rb:13-26` (Exportリンクのhref): コントローラの `assert_select` で十分。残す価値なし。
- D2 [Medium] `password_reset_test.rb:8-20` (usernameでもリセット可): POST単体＋`input[type]` の `assert_select` で恒久防止可。ブラウザに残すものなし。
- D3 [Medium] `setup_flow_test.rb` 6件中5件: `setup_controller_test.rb` (12件) と重複。残すのは正常系の着地1件＋Turboエラー表示の回帰1件のみ。
- D4 [Medium] `admin_panel_test.rb:9-59`: `admin/users_controller_test.rb` (10件) と重複。残すのは stale `lastPath` ハイジャック防止 (`navigation_controller.js`) のみ。
- D5 [Medium] `organize_test.rb` 12件中 rename/create/delete系8件: 既存コントローラテストと重複。drag による並べ替え・reparent の4件のみ残す（F1の安定化が前提）。
- D6 [Medium] `scrap_improvements_test.rb` の promote・source永続化: `scrap_items_controller_test.rb:33-58` と重複。hover＋confirm のUI経路1件＋collapse展開のみ残す。
- D7 [Medium] `bulk_todo_import_test.rb` 2件: JSON仕分けはJS純粋関数＋既存 `bulk_create` 系 (7件) でカバー。ライブプレビュー1件のみ残すか全面移行。
- D8 [High] `text_formatting_test.rb:22-55`: 純粋文字列変換でサーバ通信なし。JS単体が最適でブラウザ不要。
- D9 [High] `word_excel_paste_test.rb:204-300` (表変換): 純粋関数で全てJS単体に移せる。残すのはクリップボード分岐と画像あり貼付け1〜2件のみ。
- D10 [High] `list_continuation_test.rb` 13件相当: `send_keys` 連打は遅く不安定。jsdom＋キーイベント合成のJS単体に全面移行。ブラウザに残すものなし。
- D11 [High] `compare_view_test.rb:51-93`: 差分描画はDOM断片＋入力値で検証可。FAB→モーダル起動の配線1〜2件のみ残す。
- D12 [Low] `todo_due_dates_test.rb`・`note_sort_test.rb` のサーバ分岐部分: モデル・コントローラでカバー済み。ブラウザに残すのは表示・操作関心のみ。
- D13 [Low] `security_test.rb:51-65` (CSPランタイム注入実演): ヘッダ自体は `integration/content_security_policy_test.rb` で検証済み。費用対効果が薄く要確認。
- D14 [Low] `i18n_test.rb:46-70`: サーバ描画分はコントローラ＋ロケール切替で代替可。言語切替フローと Stimulus toast の end-to-end 2件のみ残す。
- 真にブラウザが必要で残すべき範囲: `note_conflict` (代表1〜2件に圧縮可)、`navigation_restore`・`navigation_controller_cleanup`、`sidebar_scroll` (F4緩和要)、`command_palette` (圧縮可)、`image_attachments`、KaTeX/Mermaid 描画、`responsive_layouts`。
- 削減目標: システム約100件→30〜40件。

### システムテスト以外の妥当性
カバレッジの穴:
- G1 [Medium] `test/models/concerns/positioned_test.rb:1-41`: 3件のみ。todo/scrap スコープでの `reposition!`、空配列・重複ID・順序外ID混入の境界値、並行作成時の競合テストなし。
- G2 [Medium] `test/models/folder_test.rb:63-90` (`Folder#move_to!`): 移動後の `position` に関するアサーションがゼロ。移動先での重複・順序崩れが不明。
- G3 [Medium] move 系のクロスユーザ否定テストなし（他人の notebook/folder を `target_*_id` に指定）。認可穴があっても黙認。
- G4 [Low] promote 生成 md note の `title` に関するアサーションなし。仕様の曖昧さが固定されていない。
- G5 [Low] 真の同時 PUT 競合（スレッド並行）のテストなし。クライアント側の競合吸収は重い `note_conflict` システムテストに依存。
- 良好: `Note` 自動タイトル (27件)、`TrustedHeaderLogin` (5件)、`Note#to_markdown`／画像変換に穴なし。

脆い・実装詳細結合:
- B1 [Medium] `test/models/notebook_test.rb:40-44`: フィクスチャの中身に結合（`notebooks(:one)` が position 1 占有前提）。
- B2 [Low] 時間アサーション (`home_controller_test.rb:49-64` の `assert_in_delta 5` 秒、`user_test.rb:12-18` の1秒)。CI負荷で flake し得る。
- B3 [Low] 表示用クラス・ファイル名の完全一致に結合。意図した検出でもあり一律排除は不要。
- B4 [Low] `test/i18n_completeness_test.rb`: 動的キーは走査対象外。実バグ捕獲の実績ありで有用。

fixtures:
- `fixtures :all` で全読み込みしながら実質使うのは `users` とクロスユーザ参照用の一部のみ。`todo_items`・`scrap_items` はほぼ死蔵。
- `todo_items.yml`・`scrap_items.yml` が md note に紐づくドメイン不正状態。将来 note_type 整合性を入れると一斉に赤くなる時限爆弾 [Low]。

実行速度: `rails test` 約250件で約7秒＝健全。問題は `test:system` 約100件で約152秒＋逐次化＋最大2回リトライ。主犯はフォーム経由 `sign_in_as` 約100回、毎回の `resize_to`、50件作成の sidebar_scroll、固定 sleep の累積、2ブラウザの note_conflict。`bin/ci quick` で system をスキップする運用自体は妥当。

テスト層別の件数概数: system 24ファイル約96件 / models 8ファイル約87件 / controllers 18ファイル約155〜160件 / integration 2ファイル6件 / i18n 2件 / JS単体 0。合計約350件。

移行提案の要点: (1) JS単体ランナ新設が最優先（30件超を削除・縮小可）。(2) D1〜D6 の重複は既存コントローラテストに `assert_select` 1行追加で吸収し対応システムテストを削除。(3) `sleep` 固定待ちを Capybara マッチャに置換、ピクセル完全一致を範囲アサーションに緩和、緑化したら `minitest-retry` 恒常使用をやめ失敗を可視化。(4) 下位の穴埋めは `move_to!` 後 position・move 系他ユーザID拒否・`Positioned` 境界値・promote 生成 title に各1〜3件追加。

要確認: システム件数の実測96 vs `verification.md` の104の差分。toast duration 未読のため F8 の深刻度は推定。CSP ランタイム注入テスト削除判断はセキュリティ観点の範囲外。

## 対応方針
本レポートは指摘のみ。コード変更・ブランチ作成は行っていない。修正 PR が必要になれば、対象の所見を指定して指示すること (例: 「G-2 と G-9 の修正を PR にして」)。
