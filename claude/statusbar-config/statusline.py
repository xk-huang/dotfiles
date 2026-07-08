#!/usr/bin/env python3
"""Claude Code statusline.
Reads the Status JSON from stdin and prints a single status line:
  model | effort | dir | ctx% | tokens/limit | 5h% 7d%
"""
import sys, json, os

# ---- ANSI colors (dark theme friendly) ----
def c(code, s):
    return f"\033[{code}m{s}\033[0m"
DIM, CYAN, GREEN, YELLOW, RED, MAGENTA, BLUE = "2", "36", "32", "33", "31", "35", "34"

def load_stdin():
    try:
        return json.loads(sys.stdin.read() or "{}")
    except Exception:
        return {}

def find_key(obj, needles):
    """Recursively search a nested dict/list for the first value whose key
    contains any of `needles` (case-insensitive)."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str) and any(n in k.lower() for n in needles) \
               and isinstance(v, (str, int, float)):
                return v
        for v in obj.values():
            r = find_key(v, needles)
            if r is not None:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_key(v, needles)
            if r is not None:
                return r
    return None

def abbrev_dir(path):
    if not path:
        return "?"
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        path = "~" + path[len(home):]
    return path

def context_tokens(transcript_path):
    """Sum the token footprint of the most recent assistant usage record."""
    if not transcript_path or not os.path.exists(transcript_path):
        return None
    try:
        with open(transcript_path, "r", errors="ignore") as f:
            lines = f.readlines()
    except Exception:
        return None
    for line in reversed(lines):
        line = line.strip()
        if '"usage"' not in line:
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        usage = (rec.get("message") or {}).get("usage")
        if not isinstance(usage, dict):
            continue
        return (
            usage.get("input_tokens", 0)
            + usage.get("cache_creation_input_tokens", 0)
            + usage.get("cache_read_input_tokens", 0)
            + usage.get("output_tokens", 0)
        )
    return None

def human(n):
    if n is None:
        return "?"
    if n >= 1_000_000:
        return f"{n/1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n/1_000:.1f}k"
    return str(n)

def pct_color(pct):
    return GREEN if pct < 60 else (YELLOW if pct < 85 else RED)

def usage_segs(d):
    """5h/7d rate-limit usage, e.g. `5h 4% 7d 0%`."""
    segs = []
    rl = d.get("rate_limits") or {}
    rl_bits = []
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        info = rl.get(key)
        pct = info.get("used_percentage") if isinstance(info, dict) else None
        if pct is None:
            continue
        rl_bits.append(c(DIM, f"{label} ") + c(pct_color(pct), f"{pct}%"))
    if rl_bits:
        segs.append(" ".join(rl_bits))

    return segs

def main():
    d = load_stdin()

    # Optional debug: STATUSLINE_DEBUG=1 dumps the raw Status JSON for inspection.
    if os.environ.get("STATUSLINE_DEBUG"):
        try:
            with open(os.path.expanduser("~/.claude/statusline-debug.json"), "w") as f:
                json.dump(d, f, indent=2)
        except Exception:
            pass

    model = (d.get("model") or {})
    model_name = model.get("display_name") or model.get("id") or "model"
    model_id = str(model.get("id", ""))

    # Reasoning effort lives at d["effort"]["level"]; fall back to a probe for
    # older/other schemas where it may be a bare scalar under another key.
    effort_obj = d.get("effort")
    if isinstance(effort_obj, dict):
        effort = effort_obj.get("level") or find_key(effort_obj, ["level", "effort", "reasoning"])
    elif isinstance(effort_obj, (str, int, float)):
        effort = effort_obj
    else:
        effort = find_key(d, ["effort", "reasoning"])
    effort = str(effort) if effort not in (None, "") else None

    cwd = (d.get("workspace") or {}).get("current_dir") or d.get("cwd")
    directory = abbrev_dir(cwd)

    # Context limit: 1M sessions are flagged by exceeds_200k_tokens or a [1m] model id.
    if d.get("exceeds_200k_tokens") or "1m" in model_id.lower():
        limit = 1_000_000
    else:
        limit = 200_000

    tokens = context_tokens(d.get("transcript_path"))
    if tokens is not None:
        pct = tokens / limit * 100
        ctx_seg = c(pct_color(pct), f"{pct:.0f}%")
        tok_seg = f"{human(tokens)}/{human(limit)}"
    else:
        ctx_seg = c(DIM, "?%")
        tok_seg = f"?/{human(limit)}"

    parts = [
        c(CYAN, model_name),
        c(MAGENTA, effort) if effort else c(DIM, "effort:?"),
        c(BLUE, directory),
        c(DIM, "ctx ") + ctx_seg,
        c(DIM, tok_seg),
        *usage_segs(d),
    ]
    sep = c(DIM, " | ")
    sys.stdout.write(sep.join(parts))

if __name__ == "__main__":
    main()
