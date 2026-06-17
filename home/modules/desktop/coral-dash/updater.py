#!/usr/bin/env python3
# writes data.json (system stats + colorized PUBLIC .plan) next to index.html
# every few seconds. the screensaver's WKWebView fetches it same-origin over the
# loopback server. %hidden plan lines are dropped as a safety net.
import json, os, time, subprocess, html

DIR = os.path.expanduser("~/Library/Application Support/coral-dash")
PLAN = os.path.expanduser("~/plan/plan.txt")
INTERVAL = 3


def sh(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except Exception:
        return ""


def colorize(line):
    esc = html.escape(line)
    if "%hidden" in line:
        return None
    if line.startswith("▶"):          # doing
        return f'<span class=doing>{esc}</span>'
    if line.startswith("▷"):          # next
        return f'<span class=next>{esc}</span>'
    if line.startswith("✓") or line.startswith("~"):  # done
        return f'<span class=done>{esc}</span>'
    if line.strip().lower() in ("doing", "next", "someday", "done"):
        return f'<span class=head>{esc}</span>'
    return f'<span>{esc}</span>'


def stats():
    up = sh("uptime | sed 's/.*up //; s/, *[0-9]* user.*//; s/^ *//'")
    load = sh("uptime | sed 's/.*averages*: //'")
    mem = sh("vm_stat | awk '/page size of/{ps=$8} /Pages active/{a=$3} "
             "/Pages wired/{w=$4} END{gsub(/\\./,\"\",a);gsub(/\\./,\"\",w);"
             "printf \"%.1f GB\",(a+w)*ps/1073741824}'")
    disk = sh("df -h / | awk 'NR==2{print $4\" free\"}'")
    return [["host", "coral"], ["uptime", up], ["load", load],
            ["memory", mem], ["disk", disk]]


def plan():
    if not os.path.exists(PLAN):
        return "(plan not synced to this box yet)"
    lines = [colorize(l.rstrip("\n")) for l in open(PLAN, encoding="utf-8")]
    return "\n".join(l for l in lines if l)


def main():
    os.makedirs(DIR, exist_ok=True)
    while True:
        data = {"host": "coral", "stats": stats(), "plan": plan()}
        tmp = os.path.join(DIR, ".data.json.tmp")
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f)
        os.replace(tmp, os.path.join(DIR, "data.json"))
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
