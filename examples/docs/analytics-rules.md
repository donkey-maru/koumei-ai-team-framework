# アナリティクス実装ルール

## 基本ルール

ユーザー操作（ボタン押下・画面遷移・モーダル開閉など）を追加・変更した場合は、
以下の 2 点を**必ずセットで実装**すること。

1. `lib/analytics/constants.ts` にイベント定数を定義する
2. 操作が発生する箇所で `track(ANALYTICS_EVENTS.定数名, ...)` を呼び出す

定数を定義したのに `track()` を呼び出さない実装は不可。

## CI による自動チェック

PR 時に `.ci/check-analytics-events.sh` が自動実行される。
`lib/analytics/constants.ts` に追加された定数が `ANALYTICS_EVENTS.定数名` の形で
ソースコード内に存在しない場合、CI が FAILED となり PR をブロックする。

CI が検出できるケース:
- 定数を追加したのに `track()` の呼び出しを書き忘れた → FAILED でブロック

CI が検出できないケース:
- ボタンを追加したのに定数も `track()` も書かなかった → コードレビューで確認

## 意図的に発火しない定数の扱い

将来用の定数など、意図的に `track()` を書かない場合は
`.ci/check-analytics-events.sh` の `ALLOWLIST` にその定数名を追加すること。

```bash
ALLOWLIST=("RESERVED_FUTURE_USE" "PLACEHOLDER_EVENT")
```
