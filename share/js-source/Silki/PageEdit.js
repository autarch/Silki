JSAN.use('DOM.Utils');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.PageEdit = function () {
    this.form    = $("edit-form");
    this.preview = $("preview");

    if ( ! ( this.form && this.preview ) ) {
        return;
    }

    this.toolbar = new Silki.PageEdit.Preview ();
    this.toolbar = new Silki.PageEdit.Toolbar ();

    this._resizeFormAndPreview();
};

Silki.PageEdit.prototype._resizeFormAndPreview = function () {
    /* This is a hacky guess */
    var available = window.innerHeight * 0.7;

    this.form.style.height    = available + "px";
    this.preview.style.height = available + "px";
};
