# rice.wired: the `wired` command. ask your obsidian vault from the terminal.
# the terminal-first companion to the vault's ai layer: it keyword-retrieves the
# most relevant notes and asks Claude (Anthropic Messages API) to answer strictly
# from them, printing the note names it leaned on. "jack into the wired."
#
# cross-file deps:
#   - secrets/anthropic.yaml (sops): field `wired-api-key`, materialised to a
#     0600 path this command reads. NEVER inline the key; this repo is a public
#     mirror. rotate the key by `sops set`ting that field, no code change.
#   - the vault (rice.notes, home/modules/notes/obsidian.nix) supplies the notes;
#     default path mirrors that module's default rather than depending on its
#     option, so this stays evaluable on hosts that never import notes.
#
# retrieval is keyword-based on purpose (ripgrep over the md tree): no embedding
# index to build or keep fresh, works the instant a note is written, and is
# transparent about what it fed the model. upgrade to embeddings later if recall
# ever disappoints; the interface stays the same.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.wired;

  # sops drops the key here at activation; the command reads it at call time so a
  # rotated secret is picked up on the next run with no rebuild.
  keyFile = "${config.xdg.configHome}/wired/api-key";

  wired =
    pkgs.writers.writePython3Bin "wired"
      {
        # long lines + a couple of style nits the vault-query logic reads cleaner
        # without fighting; logic is still flake8-clean otherwise.
        flakeIgnore = [
          "E501"
          "E731"
          "W605"
          "E302"
          "E305"
        ];
      }
      ''
        import argparse
        import json
        import os
        import re
        import subprocess
        import sys
        import urllib.error
        import urllib.request

        RG = "${pkgs.ripgrep}/bin/rg"
        KEYFILE = "${keyFile}"
        API = "https://api.anthropic.com/v1/messages"

        # question words that carry no retrieval signal; dropped before searching.
        STOP = set((
            "the a an and or but of to in on for with what which did do does is are "
            "was were about note notes have has that this it its from how when where "
            "who why can could would should my me you your our i we they them their "
            "get got show tell find list give please help"
        ).split())

        def eprint(*a):
            print(*a, file=sys.stderr)

        def api_key():
            try:
                return open(KEYFILE, encoding="utf-8").read().strip()
            except OSError:
                eprint("wired: api key missing at %s" % KEYFILE)
                eprint("       did sops decrypt? check the age key + `wired-api-key` in anthropic.yaml")
                sys.exit(1)

        def search_terms(q):
            words = re.findall(r"[A-Za-z0-9_+-]{3,}", q.lower())
            out, seen = [], set()
            for w in words:
                if w in STOP or w in seen:
                    continue
                seen.add(w)
                out.append(w)
            return out[:12]

        def retrieve(vault, terms, k):
            # idf-weighted: a term that matches few notes (e.g. "pac") says more
            # about relevance than a common one (e.g. "note"), so weight each
            # match by 1/df. this keeps a broad index note (a MOC that hits many
            # common words) from crowding out the specific note you asked about.
            hits = {}
            for t in terms:
                try:
                    r = subprocess.run(
                        [RG, "-l", "-i", "--type", "md",
                         "-g", "!.obsidian", "-g", "!.trash", "-g", "!templates",
                         t, vault],
                        capture_output=True, text=True)
                except FileNotFoundError:
                    eprint("wired: ripgrep missing from the closure")
                    sys.exit(2)
                hits[t] = set(r.stdout.splitlines())
            scores = {}
            for files in hits.values():
                df = len(files)
                if df == 0:
                    continue
                w = 1.0 / df
                for f in files:
                    scores[f] = scores.get(f, 0.0) + w
            ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
            return [f for f, _ in ranked[:k]]

        def build_context(files, cap=2000):
            chunks, names = [], []
            for f in files:
                try:
                    txt = open(f, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                name = os.path.splitext(os.path.basename(f))[0]
                names.append(name)
                chunks.append("### " + name + "\n" + txt[:cap])
            return "\n\n".join(chunks), names

        def ask(model, question, context, max_tokens):
            system = (
                "You answer strictly from the provided notes taken from the user's "
                "personal Obsidian vault. Cite the note names you used in square "
                "brackets like [note-name]. If the notes do not contain the answer, "
                "say so plainly instead of guessing. Be concise and direct. Do not "
                "use em dashes.")
            user = "notes:\n\n" + context + "\n\n---\n\nquestion: " + question
            payload = json.dumps({
                "model": model,
                "max_tokens": max_tokens,
                "system": system,
                "messages": [{"role": "user", "content": user}],
            }).encode()
            req = urllib.request.Request(API, data=payload, headers={
                "content-type": "application/json",
                "x-api-key": api_key(),
                "anthropic-version": "2023-06-01",
            })
            try:
                with urllib.request.urlopen(req, timeout=180) as resp:
                    data = json.load(resp)
            except urllib.error.HTTPError as e:
                body = e.read().decode(errors="replace")
                if e.code == 401:
                    eprint("wired: auth rejected (401). the key is bad or rotated.")
                    eprint("       update it: sops set secrets/anthropic.yaml '[\"wired-api-key\"]' '\"sk-ant-...\"'")
                elif e.code == 404:
                    eprint("wired: model '%s' not found (404). check --model." % model)
                elif e.code == 429:
                    eprint("wired: rate limited (429). give it a moment.")
                else:
                    eprint("wired: anthropic http %d: %s" % (e.code, body[:200]))
                sys.exit(1)
            except urllib.error.URLError as e:
                eprint("wired: cannot reach the anthropic api (%s)." % e.reason)
                eprint("       offline? the notes are still here; only the answer needs the net.")
                sys.exit(1)
            parts = [b.get("text", "") for b in data.get("content", []) if b.get("type") == "text"]
            return "".join(parts).strip()

        def main():
            ap = argparse.ArgumentParser(
                prog="wired",
                description="ask your obsidian vault, answered by claude from your own notes")
            ap.add_argument("question", nargs="+", help="what to ask your notes")
            ap.add_argument("--model", default="${cfg.model}")
            ap.add_argument("--vault", default=os.path.expanduser("${cfg.vault}"))
            ap.add_argument("-n", "--notes", type=int, default=${toString cfg.topK},
                            help="how many notes to retrieve")
            ap.add_argument("--max-tokens", type=int, default=${toString cfg.maxTokens})
            args = ap.parse_args()

            q = " ".join(args.question)
            terms = search_terms(q)
            if not terms:
                eprint("wired: nothing searchable in that question.")
                sys.exit(1)

            if not os.path.isdir(args.vault):
                eprint("wired: no vault at %s" % args.vault)
                sys.exit(1)

            files = retrieve(args.vault, terms, args.notes)
            n = len(files)
            eprint("⟢ retrieving from vault (%d note%s)..." % (n, "" if n == 1 else "s"))
            if files:
                context, names = build_context(files)
            else:
                eprint("  no keyword matches; answering from the model alone.")
                context, names = "", []

            eprint("⟢ asking claude (%s)..." % args.model)
            eprint("")
            answer = ask(args.model, q, context, args.max_tokens)
            print(answer)
            if names:
                print("\n[sources: " + ", ".join(names) + "]")

        if __name__ == "__main__":
            main()
      '';
in
{
  options.rice.wired = {
    enable = lib.mkEnableOption "the `wired` ask-my-vault command (claude)";
    model = lib.mkOption {
      type = lib.types.str;
      default = "claude-sonnet-5";
      description = "anthropic model id to answer with";
    };
    vault = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/vault";
      description = "obsidian vault to retrieve notes from";
    };
    topK = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = "how many notes to feed the model as context";
    };
    maxTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1024;
      description = "max answer length in tokens";
    };
  };

  config = lib.mkIf cfg.enable {
    # the anthropic key, decrypted to a 0600 path the command reads at call time.
    sops.secrets."wired-api-key" = {
      sopsFile = ../../../secrets/anthropic.yaml;
      path = keyFile;
      mode = "0600";
    };

    home.packages = [ wired ];
  };
}
