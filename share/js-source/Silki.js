JSAN.use('Data.Dump');
JSAN.use('DOM.Ready');
JSAN.use('Silki.FileView');
JSAN.use('Silki.PageEdit');
JSAN.use('Silki.PageTags');
JSAN.use('Silki.User');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.instrumentAll = function () {
    Silki.FileView.instrumentIframe();
    Silki.PageEdit.instrumentForm();

    new Silki.PageTags ();
};

DOM.Ready.onDOMDone( Silki.instrumentAll );
