#!/bin/bash
# Install the theme on a SOGo server. Everything lands outside the package
# tree, so a sogo upgrade cannot overwrite it.
#
#   ./deploy.sh HOST
set -euo pipefail
HOST="${1:?usage: deploy.sh <ssh-host>}"
DEST=/usr/local/share/sogo-theme

ssh "$HOST" "install -d -m 755 $DEST"
scp -q dist/theme-dark.css "$HOST:$DEST/"
scp -q brand/*.svg "$HOST:$DEST/"

ssh "$HOST" "bash -s" <<'REMOTE'
set -euo pipefail
DEST=/usr/local/share/sogo-theme
chmod 644 "$DEST"/*
restorecon -R "$DEST" 2>/dev/null || true

# mod_alias uses the FIRST matching Alias in configuration order, and
# SOGo.conf aliases the whole WebServerResources directory — hence 00-.
cat > /etc/httpd/conf.d/00-sogo-theme.conf <<'CONF'
# Dark theme and branding for SOGo. Files live in /usr/local/share, which
# belongs to no rpm, so a package upgrade cannot replace them.
# To revert: remove this file and reload httpd.
Alias /SOGo.woa/WebServerResources/css/theme-default.css /usr/local/share/sogo-theme/theme-dark.css
Alias /SOGo/WebServerResources/css/theme-default.css /usr/local/share/sogo-theme/theme-dark.css
Alias /SOGo.woa/WebServerResources/img/sogo-full.svg /usr/local/share/sogo-theme/your-logo.png
Alias /SOGo/WebServerResources/img/sogo-full.svg /usr/local/share/sogo-theme/your-logo.png
Alias /SOGo.woa/WebServerResources/img/sogo-compact.svg /usr/local/share/sogo-theme/your-mark.png
Alias /SOGo/WebServerResources/img/sogo-compact.svg /usr/local/share/sogo-theme/your-mark.png

<Directory /usr/local/share/sogo-theme>
    Require all granted
</Directory>
CONF

apachectl configtest
systemctl reload httpd

# The page requests theme-default.css?lm=<mtime of the PACKAGED file>.
# Without this touch, browsers keep serving the old theme from cache and the
# change looks like it did nothing.
touch /usr/lib64/GNUstep/SOGo/WebServerResources/css/theme-default.css
systemctl restart sogod
echo "deployed; sogod $(systemctl is-active sogod)"
REMOTE
