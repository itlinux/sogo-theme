# Branding

This repo ships no logos. SOGo's own marks are replaced by aliasing two
files, so put yours here and point the aliases at them:

    sogo-full.svg      the login page and the top bar
    sogo-compact.svg   the collapsed bar

In `/etc/httpd/conf.d/00-sogo-theme.conf`:

    Alias /SOGo.woa/WebServerResources/img/sogo-full.svg    /usr/local/share/sogo-theme/your-logo.png
    Alias /SOGo/WebServerResources/img/sogo-full.svg        /usr/local/share/sogo-theme/your-logo.png
    Alias /SOGo.woa/WebServerResources/img/sogo-compact.svg /usr/local/share/sogo-theme/your-mark.png
    Alias /SOGo/WebServerResources/img/sogo-compact.svg     /usr/local/share/sogo-theme/your-mark.png

The alias target may be a PNG even though the request path ends in `.svg`:
Apache sets the content type from the file on disk, and the browser follows
that. A transparent background matters — the bar is dark.

`/Microsoft-Server-ActiveSync` cannot be renamed. iOS and Android hardcode it.
