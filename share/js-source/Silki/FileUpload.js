JSAN.use('AjaxUpload');
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

    new AjaxUpload( '#file',
                    { "action":       this._form.action,
                      "name":         $("file").name,
                      "data":         { "page_id": $("page_id").value },
                      "autoSubmit":   true,
                      "responseType": "json",
                      "onSubmit":     function () { self._showUploadSpinner.apply( self, arguments ); },
                      "onComplete":   function () { self._updateFileList.apply( self, arguments ); }
                    }
                  );
};

Silki.FileUpload.prototype._showUploadSpinner = function () {
    this._lightbox.show();
};

Silki.FileUpload.prototype._updateFileList = function ( file, response ) {
    this._lightbox.hide();

    return;
};