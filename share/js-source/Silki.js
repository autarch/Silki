JSAN.use('DOM.Ready');
JSAN.use('Silki.PageEdit');


if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.instrumentAll = function () {
    Silki.PageEdit.instrumentForm();
};

DOM.Ready.onDOMDone( Silki.instrumentAll );
