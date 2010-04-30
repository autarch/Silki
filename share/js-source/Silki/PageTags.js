JSAN.use('DOM.Events');
JSAN.use('HTTP.Request');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

Silki.PageTags = function () {
    var form = $("tags");

    if ( ! form ) {
        return;
    }

    this._form = form;

    this._instrumentForm();
};

Silki.PageTags.prototype._instrumentForm = function () {
    var self = this;

    DOM.Events.addListener(
        this._form,
        "submit",
        function (e) {
            e.preventDefault();
            if ( e.stopPropogation ) {
                e.stopPropagation();
            }

            self._submitForm();
        }
    );
};

Silki.PageTags.prototype._submitForm = function () {
    var tags = this._form.tags.value;

    if ( ! tags && tags.length ) {
        return;
    }

    var self = this;

    var req = new HTTP.Request( {
        "uri":        this._form.action,
        "parameters": { "tags": tags },
        "onComplete": function (trans) { self._updateTagList(trans); },
    } );

    req.request();
};

Silki.PageTags.prototype._updateTagList = function (trans) {
    alert("complete");
};
