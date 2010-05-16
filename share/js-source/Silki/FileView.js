JSAN.use('DOM.Utils');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

if ( typeof Silki.FileView == "undefined" ) {
    Silki.FileView = {};
}

Silki.FileView = function () {
    var iframe = $("file-view-iframe");

    if ( ! iframe ) {
        return;
    }

    /* This should really calculate how much space is available after
     accounting for header and footer, but that is annoying to do (should
     steal or use jquery's version) */
    iframe.height = window.innerHeight * 0.7;
};
