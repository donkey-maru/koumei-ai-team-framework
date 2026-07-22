# レビュー拡張モード

## セキュリティ監査モード

`/koumei-review security` または `/koumei-review --security` で実行。

通常のレビュー観点に加えてOWASP Top 10 + STRIDE の完全チェックを実施する。

レビュー結果に以下を追加で含める:
- OWASP Top 10 各項目の評価（✅/⚠️/❌/N/A）
- STRIDE 脅威分析結果
- セキュリティスコア（X/10）
- スコアが 8/10 未満の場合は VERDICT: NEEDS_REVISION を強制

レビュー結果のファイル名: `task-{番号}-security-review.md`

## セカンドオピニオンモード

`/koumei-review second-opinion` または `/koumei-review --second-opinion` で実行。

### 前提条件
- TEAM.md の「セカンドオピニオン設定」にモデルが定義されていること
- 未定義の場合は通知して通常レビューのみ実施

### 手順
1. 通常レビューを実行し、Devil's Advocateレビュー結果を作成
2. TEAM.md の「セカンドオピニオン設定」セクションを確認
   - セクション内にHTMLコメント外の通常Markdownテーブルが存在する場合 → 有効
   - テーブルがHTMLコメント内 or セクション自体なし → 未設定
3. 設定されたモデルに対してレビュー依頼（Bash経由CLI呼び出し）
4. 両モデルの結果を比較し、差異分析
5. 統合VERDICTを算出
6. `task-{番号}-second-opinion-review.md` として保存

**注意**: セカンドオピニオンモデルが利用不可の場合、エラーとせず通常レビュー結果のみで完了する。

### 統合VERDICTの判定ルール
- どちらか一方が NEEDS_FIX → 統合VERDICT は NEEDS_FIX
- Critical指摘は両モデルの指摘を全てカウント
- 同一箇所への重複指摘は厳しい方の重大度を採用

### 他モードとの組み合わせ
`security` + `second-opinion` 同時指定:
- セキュリティ監査結果を含むレビューに対してセカンドオピニオンを実施
- 出力ファイル: `task-{番号}-security-second-opinion-review.md`
