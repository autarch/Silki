JSAN.use('DOM.Events');
JSAN.use('DOM.Utils');
JSAN.use('Widget.Lightbox2');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

if ( typeof Silki.FileUpload == "undefined" ) {
    Silki.FileUpload = {};
}

Silki.FileUpload = function () {
    var form = $("file-upload-form");

    if ( ! form ) {
        return;
    }

    this._form = form;
    this._lightbox = new Widget.Lightbox2 ( { "color":         "#eee",
                                              "opacity":       0.5,
                                              "sourceElement": $("upload-lightbox") } );
};

Silki.FileUpload.prototype.instrumentForm = function () {
    if ( ! this._form ) {
        return;
    }

    var self = this;

    DOM.Events.addListenever( this._form,
                              "submit",
                              function () { self._lightbox.show(); }
                            );
};
