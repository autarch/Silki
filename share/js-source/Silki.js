JSAN.use('DOM.Ready');
JSAN.use('Silki.FileView');
JSAN.use('Silki.PageTags');
JSAN.use('Silki.ProcessStatus');
JSAN.use('Silki.SystemLogs');
JSAN.use('Silki.URI');
JSAN.use('Silki.User');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.instrumentAll = function () {
    new Silki.FileView ();
    new Silki.PageTags ();
    new Silki.ProcessStatus ();
    new Silki.SystemLogs ();
};

DOM.Ready.onDOMDone( Silki.instrumentAll );
