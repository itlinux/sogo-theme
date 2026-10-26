# sogo-theme

A dark theme for SOGo, installed so that a package upgrade cannot undo it.

SOGo ships no dark mode. Verified against 5.12.12: no `prefers-color-scheme`
rules, no `md-*-theme-dark` classes, no configuration key, and nothing in the
JavaScript bundles. Upstream has never added one. This builds one and gets it
in front of the packaged files without touching them.

Tested on SOGo 5.12.12 with Apache on RHEL 9 and RHEL 10.

## Install

    git clone <this repo> && cd sogo-theme
    ./update.sh <your-ssh-host> [more hosts…]

Everything lands in `/usr/local/share/sogo-theme`, which belongs to no rpm.
The Apache aliases go in `/etc/httpd/conf.d/00-sogo-theme.conf`. To revert,
delete that file and reload httpd — nothing inside SOGo's package tree is
modified at any point.

Then put your own logo in place of SOGo's — see **Your logo, not mine**
below. Nothing else needs editing to run it.

## Three things that will cost you an hour if nobody tells you

**1. The Apache config must sort before SOGo's.** `mod_alias` uses the *first*
matching `Alias` in configuration order, and SOGo's own config aliases the
whole `WebServerResources` directory. A file sorting after `SOGo.conf` never
wins — hence `00-`.

**2. The cache-buster makes changes look like no-ops.** The page requests
`theme-default.css?lm=<mtime of the PACKAGED file>`. Replacing the file behind
an alias does not change that mtime, so browsers keep serving the old
stylesheet and nothing appears to happen. `update.sh` touches the packaged
file to force a new value. A SOGo upgrade changes the mtime anyway, so
upgrades self-bust the cache.

**3. SOGo injects its own palette at runtime**, as inline `<style>` rules built
from its green palette:

    .md-default-theme.md-accent.md-bg { background-color: rgb(86,176,76);
                                        color: #fff !important }

Those land *after* any stylesheet you serve, with equal specificity, so they
win. This is why the login page stays green and white while everything served
from `theme-default.css` is already dark. Prefixing a selector with `html`
raises specificity enough to take it back. See the end of
`src/overrides.css`.

## Rebuilding the stylesheet

`js/theme.js` inside SOGo is build-time source, not something the page loads,
and rebuilding it the official way needs SOGo's source tree and its npm
toolchain — which has no business on a mail server.

Instead: Angular Material carries the theme template inside its own
JavaScript, as `$MD_THEME_CSS`, with 624 `THEME_NAME` placeholders. Loading
angular and angular-material in a throwaway page, configuring
`$mdThemingProvider`, and collecting the `<style>` elements it injects
produces byte-equivalent output — about 436 KB, against the 441 KB SOGo ships.

    # the exact versions SOGo serves. cdnjs does NOT host angular-animate or
    # angular-aria under angular.js/1.8.3/, so take all four from a server:
    scp HOST:/usr/lib64/GNUstep/SOGo/WebServerResources/js/vendor/{angular,angular-animate,angular-aria,angular-material}.min.js generator/
    cd generator && python3 -m http.server 8791
    # open http://127.0.0.1:8791/theme-gen.html and read window.__themeCss

Collect from the injected `<style>` tags, **not** by filtering
`document.styleSheets` for `-theme`: SOGo's own `styles.css` is full of
already-substituted `md-default-theme` rules and swamps the result.

Then `cat theme-generated.css src/overrides.css > dist/theme-dark.css`, which
is what `update.sh` does.

## Choosing your own colours

Edit the palettes at the top of `generator/theme-gen.html` and regenerate.
The shipped palette is a neutral dark grey with an orange accent; the
structure matters more than the values:

    base      #272727   the main surface
    mantle    #1f1f1f   toolbars, sidebar, the form half of the login page
    crust     #181818   the darkest surfaces
    surfaces  #323232 / #3d3d3d / #4a4a4a
    text      #d0d7e2
    accent    #ff8c00

**The hue mapping is the whole game.** SOGo paints specific chrome from
specific hues:

    primary '400' -> top toolbar        primary '600' -> sidebar toolbar
    accent  '600' -> FAB                accent  '300' -> centre list toolbar

Put your accent colour on the *primary* palette and you get a toolbar painted
in it, which looks nothing like a theme. Dark surfaces belong on the hues that
fill large areas; the accent belongs on the FAB and the active states. Every
palette must define all 14 hues or Angular Material throws
`Missing colors 800, 900, A700 in palette <name>` at configuration time.

## What a theme cannot reach

SOGo hardcodes light surfaces in its own `styles.css`, which is why half the
interface stays white when only the generated theme is swapped.
`src/overrides.css` covers them:

    .daysView / md-toolbar.monthView   #fff      calendar day-header row
    .days / .monthView                 #fafafa   calendar grid body
    .outOfDay                          #fafafa   out-of-hours band
    .view-list / .view-detail          #fff      message list, reading pane
    .md-whiteframe-3dp                 #fafafa   the login card, BOTH halves
    md-sidenav                         border-right: 1px solid #fff
    md-list-item hover                 rgba(158,158,158,.2)
    .clickableHourCell                 border rgba(0,0,0,.26) — invisible on dark
    .sg-form-section / .sg-skeleton / .sg-chip-color

Avoid broad selectors such as `[class*="border"]`. Tried; it tints things
unpredictably.

**A generated dark theme leaves input text transparent** —
`color: rgba(0,0,0,0)` on `input` — so you cannot see what you type, including
on the login page. The override needs `!important`, because a more specific
SOGo rule wins otherwise, and `-webkit-text-fill-color` alone is non-standard.

**Autofill paints its own background.** A field the browser has filled gets a
background from the browser, not from your stylesheet. Match the inset
box-shadow to the surface underneath or the username lights up against
everything around it the moment a password manager touches it.

## Your logo, not mine

No logos are shipped here, and the mark in this project's screenshots is
the author's own. Swapping it for yours is two `scp`s and four `Alias` lines, with
SOGo's own files left untouched:

    scp my-logo.png my-mark.png HOST:/usr/local/share/sogo-theme/

then in `/etc/httpd/conf.d/00-sogo-theme.conf`:

    Alias /SOGo.woa/WebServerResources/img/sogo-full.svg    /usr/local/share/sogo-theme/my-logo.png
    Alias /SOGo/WebServerResources/img/sogo-full.svg        /usr/local/share/sogo-theme/my-logo.png
    Alias /SOGo.woa/WebServerResources/img/sogo-compact.svg /usr/local/share/sogo-theme/my-mark.png
    Alias /SOGo/WebServerResources/img/sogo-compact.svg     /usr/local/share/sogo-theme/my-mark.png

    systemctl reload httpd
    touch /usr/lib64/GNUstep/SOGo/WebServerResources/css/theme-default.css

A PNG behind a `.svg` path is fine — Apache types the response from the file
on disk. Use a transparent background; the bar is dark. Full notes, including
sizing and what cannot be rebranded, are in `brand/README.md`.

## Restarting sogod

It drops anyone currently using webmail into Apache's "Proxy Error — Error
reading from remote server" for a few seconds while the children respawn.
Harmless, but worth warning users on a busy server. `update.sh` restarts
sogod on every run, because the cache-buster touch needs it.

## Licence

MIT for the hand-written parts; see LICENSE for how that relates to Angular
Material's output and to SOGo itself.

SOGo is GPL and genuinely open source. Note that its **stable** EL9/EL10 RPMs
sit behind an Alinto support contract — `packages.sogo.nu/release/…` answers
401 — while the nightly repository is open. That is packaging, not licensing.
