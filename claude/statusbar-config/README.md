# Claude Code Statusbar

A custom status line for [Claude Code](https://claude.com/claude-code) that shows the
current model, reasoning effort, working directory, context usage, and rate-limit usage
in a single compact line.

## What it looks like

```
Opus 4.8 (1M context) | high | ~/code/slime | ctx 34% | 341.2k/1.0M | 5h 4% 7d 0%
```

Reading left → right, separated by ` | `:

| Segment        | Example              | Meaning |
|----------------|----------------------|---------|
| **model**      | `Opus 4.8 (1M context)` | Active model display name |
| **effort**     | `high`               | Reasoning/thinking effort level |
| **directory**  | `~/code/slime`       | Current working dir (home shortened to `~`) |
| **context %**  | `ctx 34%`            | How full the context window is |
| **tokens**     | `341.2k/1.0M`        | Tokens used / context limit |
| **rate limit** | `5h 4% 7d 0%`        | Percent of your 5-hour and 7-day usage limits consumed |

Percentages are color-coded: **green** < 60%, **yellow** 60–85%, **red** ≥ 85%.
The context limit auto-detects 1M-token sessions (`[1m]` models or `exceeds_200k_tokens`),
otherwise assumes 200k.

## Files

| File | Purpose |
|------|---------|
| `statusline.py` | The status line script. Reads Claude Code's status JSON on stdin, prints one line. |
| `settings.example.json` | The `settings.json` snippet that wires the script into Claude Code. |

## Requirements

- **Python 3** available on your `PATH` (the script uses only the standard library — no pip installs).
- Claude Code (any recent version that supports `command`-type status lines).

## Install

1. **Copy the script** into your Claude config directory:

   ```bash
   cp statusline.py ~/.claude/statusline.py
   chmod +x ~/.claude/statusline.py
   ```

2. **Wire it up** in `~/.claude/settings.json`. Add the `statusLine` block from
   `settings.example.json` (merge it into your existing settings — don't overwrite the
   whole file):

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "python3 ~/.claude/statusline.py"
     }
   }
   ```

3. **Reload** Claude Code (restart the session, or run `/config`). The status line appears
   at the bottom of the interface.

> **Note:** The script path in the command must match wherever you put `statusline.py`.
> If you keep it somewhere other than `~/.claude/`, update the `command` accordingly.

## How it works

Claude Code runs the `command` on every status refresh, passing a JSON status object on
**stdin**. `statusline.py`:

1. Parses that JSON (model, effort, workspace dir, transcript path, rate limits).
2. Opens the session **transcript** to sum the tokens of the latest assistant turn
   (input + cache read + cache creation + output) for the live context estimate.
3. Prints one ANSI-colored line to **stdout**, which Claude Code renders as the status bar.

Anything printed to stdout becomes the status line, so you can freely edit the layout,
colors, or segments in `statusline.py`.

## Customizing

The script is plain, dependency-free Python — edit `statusline.py` directly:

- **Reorder / remove segments** — change the `parts` list in `main()`.
- **Colors** — tweak the ANSI codes near the top (`DIM`, `CYAN`, `GREEN`, …) or the
  thresholds in `pct_color()`.
- **Token limits** — adjust the 200k / 1M logic in `main()`.

### Debugging

Set `STATUSLINE_DEBUG=1` in the environment to dump the raw status JSON Claude Code sends
to `~/.claude/statusline-debug.json`. Useful for discovering fields you want to display.

You can also test the script by hand:

```bash
echo '{"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"workspace":{"current_dir":"/home/me/proj"}}' \
  | python3 statusline.py
```
