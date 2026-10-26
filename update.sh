#!/bin/bash
# Rebuild the stylesheet and push it to every SOGo server.
#
#   ./update.sh HOST [HOST...]  rebuild and deploy
#   ./update.sh --build         rebuild only, deploy nothing
#
# The theme is src/theme-generated.css (Angular Material's output, see README
# for how to regenerate) plus src/overrides.css (everything no AM theme can
# reach). dist/theme-dark.css is the two concatenated.
set -euo pipefail
cd "$(dirname "$0")"

BUILD_ONLY=0
[ "${1:-}" = "--build" ] && { BUILD_ONLY=1; shift; }
HOSTS="${*:-}"
[ -n "$HOSTS" ] || { echo "usage: $0 HOST [HOST...]   (or --build)" >&2; exit 1; }

for f in src/theme-generated.css src/overrides.css; do
  [ -s "$f" ] || { echo "missing or empty: $f" >&2; exit 1; }
done

cat src/theme-generated.css src/overrides.css > dist/theme-dark.css
printf 'built dist/theme-dark.css  %s bytes\n' "$(wc -c < dist/theme-dark.css)"

# A theme that lost its palette is worse than no rebuild: check the surfaces
# and the accent actually survived.
for want in 'rgb(39,39,39)' 'rgb(31,31,31)' 'rgb(255,140,0)'; do
  n=$(grep -oF "$want" dist/theme-dark.css | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] || { echo "  FAILED: $want missing from the build" >&2; exit 1; }
  printf '  %-18s %s uses\n' "$want" "$n"
done

[ "$BUILD_ONLY" -eq 1 ] && { echo "build only, nothing deployed"; exit 0; }

for h in $HOSTS; do
  echo "=== $h ==="
  ssh "$h" "install -d -m 755 /usr/local/share/sogo-theme"
  scp -q dist/theme-dark.css "$h:/usr/local/share/sogo-theme/theme-dark.css"
  scp -q brand/*.png brand/*.svg "$h:/usr/local/share/sogo-theme/" 2>/dev/null || true

  ssh "$h" "bash -s" <<'REMOTE'
set -euo pipefail
chmod 644 /usr/local/share/sogo-theme/* 2>/dev/null || true
restorecon -R /usr/local/share/sogo-theme 2>/dev/null || true

apachectl configtest >/dev/null
systemctl reload httpd

# The page asks for theme-default.css?lm=<mtime of the PACKAGED file>.
# Without this touch, browsers keep the old theme and the change looks like
# it did nothing.
touch /usr/lib64/GNUstep/SOGo/WebServerResources/css/theme-default.css
systemctl restart sogod
sleep 4
printf '  sogod %s, httpd %s\n' "$(systemctl is-active sogod)" "$(systemctl is-active httpd)"
REMOTE

  host=$(ssh "$h" hostname)
  lm=$(curl -s --max-time 20 "https://$host/SOGo/" | grep -oE 'theme-default\.css\?lm=[0-9]+' | head -1 | cut -d= -f2)
  size=$(curl -s --max-time 25 -o /dev/null -w '%{size_download}' \
           "https://$host/SOGo.woa/WebServerResources/css/theme-default.css?lm=$lm")
  printf '  serving %s bytes as theme-default.css\n' "$size"
done
