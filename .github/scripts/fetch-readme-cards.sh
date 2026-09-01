#!/usr/bin/env bash
# Fetch the README cards once and store them in assets/ so the README never
# depends on a third-party host being up at page-view time.
#
# The public instances of github-readme-stats / github-profile-trophy regularly
# return 402 (Vercel quota) or 503 (GitHub API rate limit), which is what breaks
# the images in the README. Each card below therefore lists several hosts; the
# first one that answers with a real SVG wins. If every host fails, the card
# already in assets/ is kept instead of being overwritten with an error image.

set -uo pipefail

USER_NAME="${USERNAME:-tranviet0710}"
OUT_DIR="${OUT_DIR:-assets}"
MIN_BYTES=1500

mkdir -p "$OUT_DIR"

failed=0

fetch_card() {
  local name="$1"; shift
  local tmp status size
  tmp="$(mktemp)"

  for url in "$@"; do
    url="${url//\{user\}/$USER_NAME}"
    # content_type is left out on purpose: it can contain spaces ("; charset=utf-8")
    IFS=' ' read -r status size < <(
      curl -sL -m 45 -A "readme-cards-fetcher" \
        -o "$tmp" -w '%{http_code} %{size_download}\n' "$url"
    )
    if [ "$status" != "200" ]; then
      echo "  miss ($status) ${url%%\?*}"
      continue
    fi
    if [ "${size:-0}" -lt "$MIN_BYTES" ]; then
      echo "  miss (${size}B, too small) ${url%%\?*}"
      continue
    fi
    if ! grep -q "<svg" "$tmp"; then
      echo "  miss (not an svg) ${url%%\?*}"
      continue
    fi
    if grep -qE "Something went wrong|Maximum retries|rate limit|Bad credentials" "$tmp"; then
      echo "  miss (error card) ${url%%\?*}"
      continue
    fi
    mv "$tmp" "$OUT_DIR/$name.svg"
    chmod 644 "$OUT_DIR/$name.svg"
    echo "  ok   (${size}B) $name <- ${url%%\?*}"
    return 0
  done

  rm -f "$tmp"
  if [ -s "$OUT_DIR/$name.svg" ]; then
    echo "  WARN $name: every host failed, keeping the existing card"
  else
    echo "  FAIL $name: every host failed and there is no cached card"
    failed=1
  fi
  return 1
}

echo "stats:"
fetch_card stats \
  "https://github-readme-stats.vercel.app/api?username={user}&show_icons=true&theme=transparent&rank_icon=github&include_all_commits=true&count_private=true&hide_border=true" \
  "https://github-readme-stats-salesp07.vercel.app/api?username={user}&show_icons=true&theme=transparent&rank_icon=github&include_all_commits=true&count_private=true&hide_border=true"

echo "top-langs:"
fetch_card top-langs \
  "https://github-readme-stats.vercel.app/api/top-langs/?username={user}&layout=compact&theme=transparent&langs_count=8&hide_border=true" \
  "https://github-readme-stats-salesp07.vercel.app/api/top-langs/?username={user}&layout=compact&theme=transparent&langs_count=8&hide_border=true"

echo "activity-graph:"
fetch_card activity-graph \
  "https://github-readme-activity-graph.vercel.app/graph?username={user}&theme=github-compact&hide_border=true" \
  "https://githubactivitygraph.vercel.app/graph?username={user}&theme=github-compact&hide_border=true"

echo "trophies:"
fetch_card trophies \
  "https://github-profile-trophy.vercel.app/?username={user}&theme=transparent&no-frame=true&row=1&column=7&margin-w=15&margin-h=15" \
  "https://github-trophies.vercel.app/?username={user}&theme=transparent&no-frame=true&row=1&column=7&margin-w=15&margin-h=15" \
  "https://profile-trophy.vercel.app/?username={user}&theme=transparent&no-frame=true&row=1&column=7&margin-w=15&margin-h=15"

exit "$failed"
