# Use your own logo

This repository ships no logos. The one in the screenshots is the author's —
replacing it with yours is the first thing to do, and it takes two minutes.

SOGo's own marks are never edited. They are left in place and shadowed by
Apache aliases, so a package upgrade cannot undo your branding, and deleting
one config file puts SOGo's own marks back.

## The two files SOGo asks for

    sogo-full.svg      the login page, and the top bar once signed in
    sogo-compact.svg   the collapsed bar on narrow screens

## Steps

1. Put your files on the server, beside the stylesheet:

       scp my-logo.png my-mark.png HOST:/usr/local/share/sogo-theme/
       ssh HOST 'chmod 644 /usr/local/share/sogo-theme/my-*.png'

2. Add the aliases to `/etc/httpd/conf.d/00-sogo-theme.conf`:

       Alias /SOGo.woa/WebServerResources/img/sogo-full.svg    /usr/local/share/sogo-theme/my-logo.png
       Alias /SOGo/WebServerResources/img/sogo-full.svg        /usr/local/share/sogo-theme/my-logo.png
       Alias /SOGo.woa/WebServerResources/img/sogo-compact.svg /usr/local/share/sogo-theme/my-mark.png
       Alias /SOGo/WebServerResources/img/sogo-compact.svg     /usr/local/share/sogo-theme/my-mark.png

   Both spellings are needed: SOGo serves itself under `/SOGo.woa/` and under
   `/SOGo/` depending on how it was reached.

3. Apply, and force browsers to refetch:

       ssh HOST 'apachectl configtest && systemctl reload httpd'
       ssh HOST 'touch /usr/lib64/GNUstep/SOGo/WebServerResources/css/theme-default.css'

   That last line matters — see the cache-buster note in the main README. The
   page asks for assets with a query string derived from the packaged file's
   mtime, so without it your logo may not appear and nothing will look wrong.

`deploy.sh` does all three for the stylesheet already; add your two `Alias`
pairs to the heredoc in it and your logo ships with every deploy.

## Things that will catch you out

**A PNG at a `.svg` path is fine.** Apache sets the content type from the file
on disk, not from the URL, and the browser follows that. Name the alias target
whatever you like.

**Use a transparent background.** The bar behind it is dark. A logo exported
on white arrives as a white rectangle.

**Size it for a small bar.** The login mark renders around 200px wide and the
top bar is smaller again. Export at 2x for retina; beyond that you are paying
bytes on every page load for pixels nobody sees.

**Check it against both surfaces.** The login page puts the logo on one shade
and the sign-in card on a darker one, so a logo that reads well in isolation
can vanish against one of them.

## What cannot be rebranded

`/Microsoft-Server-ActiveSync` is hardcoded in iOS and Android. The path stays.

The web interface can be reached from a friendlier path with a redirect, but
not genuinely moved: SOGo bakes `/SOGo` into the URLs it generates, so a real
remap means rewriting its HTML and JavaScript on every response, and breaks
again at each update.
