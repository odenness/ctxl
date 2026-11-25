# ctxl

A context-window meter for the [Claude Code status line](https://code.claude.com/docs/en/statusline).

```
ctx [████░░░░░░] 42% 84k/200k
```

Green under 60%, yellow from 60%, red with `⚠` from 80% (before auto-compact kicks in).
Shows `ctx: --` until the first response of a session and right after `/compact`.

## Install

Requires `jq`.

```sh
cp statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
```

Then in `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "refreshInterval": 5
}
```

## Why not just `/context`?

`/context` gives a detailed breakdown on demand. This keeps the number in view all the time, so you
can compact or start fresh before quality drops, without having to remember to check.
