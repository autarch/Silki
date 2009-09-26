JSAN.use('DOM.Events');
JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('Textarea.Text');

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
