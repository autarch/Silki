Textarea = function (textarea) {
    if ( textarea.tagName != "TEXTAREA" ) {
        throw "Textarea.js requires a textarea as its constructor argument";
    }

    this.textarea = textarea;
};

if ( document.selection && document.selection.createRange ) {
    Textarea.prototype.selectedText = function () {
        var text = document.selection.createRange().text;

        if ( typeof text == "undefined" ) {
            return "";
        }

        return text;
    };

    Textarea.prototype.replaceOrInsertText = function ( text, move_cursor ) {
        document.selection.createRange().text = text;

        if (move_cursor) {
            this.textarea.caretPos = document.selection.createRange().duplicate();
        }
    };
}
else {
    Textarea.prototype.selectedText = function () {
        var start = this.textarea.selectionStart;
        var end = this.textarea.selectionEnd;

        var text = this.textarea.value.substring( start, end );

        if ( typeof text == "undefined" ) {
            return "";
        }

        return text;
    };

    Textarea.prototype.replaceOrInsertText = function ( text, move_cursor ) {
        var start = this.textarea.selectionStart;
        var end = this.textarea.selectionEnd;

        this.textarea.value =
            this.textarea.value.substring( 0, start ) + text +
            this.textarea.value.substring( end, this.textarea.value.length );
    };
}
