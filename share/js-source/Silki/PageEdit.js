JSAN.use('DOM.Utils');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

if ( typeof Silki.PageEdit == "undefined" ) {
    Silki.PageEdit = {};
}

Silki.PageEdit.instrumentForm = function () {
    var form = $("page-edit-form");

    if ( ! form ) {
        return;
    }

    CKEDITOR.replace("page-content");
};
