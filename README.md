# ctxl

A context-window meter for the [Claude Code status line](https://code.claude.com/docs/en/statusline).

```
ctx [████░░░░░░] 42% 84k/200k                   £0.95  ◔ 32% ↻2h14m
```

**Left: context window.** Green under 60%, yellow from 60%, red with `⚠` from 80% (before
auto-compact kicks in). Shows `ctx: --` until the first response of a session and right after `/compact`.

**Right: 5-hour session usage**, pinned to the right edge. The circle fills ○ ◔ ◑ ◕ ● as you use
your claude.ai session limit, with the time until it resets. Cyan, then yellow from 60%, red from 80%.
Only shown on Pro / Max / Ultra plans, after the first response (Claude Code doesn't send the data otherwise).

**Session cost in £ (optional).** Turn it on or off with `ctxl cost`. It's Claude Code's estimate
at API list prices (`cost.total_cost_usd`), converted at the day's ECB rate. That rate is cached and
refreshed in the background once a day. On a Pro/Max plan this isn't what you pay, but it's a useful
measure of how heavy a session is. It resets when `/clear` starts a new session.

```
ctxl cost          # toggle (or: ctxl cost on / ctxl cost off)
ctxl rate          # fetch today's USD→GBP rate now
ctxl rate 0.78     # or pin your own
ctxl status
```

## Install

Requires `jq` (and `curl` for the £ rate).

```sh
cp statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
ln -sf "$PWD/ctxl" ~/.local/bin/ctxl     # any directory on your PATH
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
