# ctxl

A context-window meter for the [Claude Code status line](https://code.claude.com/docs/en/statusline).

```
ctx [████░░░░░░] 42% 84k/200k                          ◔ 32% ↻2h14m
```

**Left: context window.** Green under 60%, yellow from 60%, red with `⚠` from 80% (before
auto-compact kicks in). Shows `ctx: --` until the first response of a session and right after `/compact`.

**Right: 5-hour session usage**, pinned to the right edge. The circle fills ○ ◔ ◑ ◕ ● as you use
your claude.ai session limit, with the time until it resets. Cyan, then yellow from 60%, red from 80%.
Only shown on Pro / Max / Ultra plans, after the first response (Claude Code doesn't send the data otherwise).

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
