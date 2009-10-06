JSAN.use('DOM.Ready');
JSAN.use('Silki.FileUpload');
JSAN.use('Silki.PageEdit');
JSAN.use('Silki.User');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.instrumentAll = function () {
    ( new Silki.FileUpload ).instrumentForm();
    Silki.PageEdit.instrumentForm();
};

DOM.Ready.onDOMDone( Silki.instrumentAll );
