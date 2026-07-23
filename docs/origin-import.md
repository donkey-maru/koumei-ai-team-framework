# origin 取り込み記録

本リポジトリの `templates/` 配下のエージェント定義・スキル・Hooks は、
上流の koumei（origin）からスナップショット取り込みしたものをベースにしている。

| 項目 | 内容 |
|---|---|
| 取り込み元 | https://github.com/kuruusuniku/koumei |
| 取り込みコミット | `a00de20`（Merge pull request #13 from kuruusuniku/feature/review-timeout-switch） |
| ライセンス | MIT（取り込み元 README 記載） |
| 取り込み範囲 | `templates/.agents/`（TEAM.md・全ロール CLAUDE.md・custom-roles）、`templates/.claude/skills/`（8スキル + docs）、`templates/hooks/`（4スクリプト）、`templates/.claude/settings.json` |

## 取り込み時の変換

- `.md` → `.md.tmpl` に改名（本リポジトリのテンプレートエンジンで変数展開するため）
- 配置換え: `.agents/{role}/CLAUDE.md` → `templates/agents/{role}/CLAUDE.md.tmpl`、`.claude/skills/` → `templates/skills/`、`.claude/settings.json` → `templates/claude/settings.json`
- `hooks/quality-gate.sh` の他フレームワーク（tachikoma）由来デッドコードを削除
- `.gitkeep` は取り込まず、setup.sh がディレクトリ生成時に付与

## 上流への追従方針

追従義務はなし。origin 側の有用な改善のみ手動で移植する。差分確認は:

```bash
cd /path/to/koumei-origin
git fetch
git log a00de20..origin/main --oneline
```
