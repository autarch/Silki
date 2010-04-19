if ( typeof Textarea == "undefined" ) {
    Textarea = {};
}

Textarea.Text = function (textarea) {
    if ( textarea.tagName != "TEXTAREA" ) {
        throw "Textarea.Text requires a textarea as its constructor argument";
    }

    this.textarea = textarea;
};

/* IE and Opera */
if ( document.selection && document.selection.createRange ) {
    Textarea.Text.prototype.selectedText = function () {
        var text = document.selection.createRange().text;

        if ( typeof text == "undefined" ) {
            return "";
        }

        return text;
    };

    Textarea.Text.prototype.replaceSelectedText = function (text) {
        document.selection.createRange().text = text;

        this.textarea.caretPos = document.selection.createRange().duplicate();
    };
}
/* Firefox, Safari, and others */
else {
    Textarea.Text.prototype.selectedText = function () {
        var start = this.textarea.selectionStart;
        var end = this.textarea.selectionEnd;

        var text = this.textarea.value.substring( start, end );

        if ( typeof text == "undefined" ) {
            return "";
        }

        return text;
    };

    Textarea.Text.prototype.replaceSelectedText = function (text) {
        var start = this.textarea.selectionStart;
        var end = this.textarea.selectionEnd;

        var scroll = this.textarea.scrollTop;

        this.textarea.value =
            this.textarea.value.substring( 0, start )
            + text
            + this.textarea.value.substring( end, this.textarea.value.length );

        this.textarea.focus();

        this.textarea.selectionStart = start + text.length;
        this.textarea.selectionEnd = start + text.length;
        this.textarea.scrollTop = scroll;
    };

    Textarea.Text.prototype.caretPosition = function () {
        return this.textarea.selectionStart;
    };
}

if ( document.createElement("textarea").setSelectionRange ) {
    Textarea.Text.prototype.moveCaret = function (offset) {
        var new_pos = this.caretPosition() + offset;

        this.textarea.setSelectionRange( new_pos, new_pos );
    };
}
else {
    Textarea.Text.prototype.moveCaret = function (offset) {
        var range = this.textarea.createTextRange();
        range.collapse(true);
        range.moveEnd( "character", this.caretPosition() + offset );
        range.moveStart( "character", this.caretPosition() + offset );
        range.select();
    };
}

Textarea.Text.prototype.previousLine = function () {
    var text = this.textarea.value;

    var last_line_end = text.lastIndexOf( "\n", this.caretPosition() );

    if ( ! last_line_end ) {
        return "";
    }
    else {
        var prev_line_start = text.lastIndexOf( "\n", last_line_end - 1 ) + 1;
        return text.substr( prev_line_start, last_line_end - prev_line_start );
    }
}

Textarea.Text.prototype.caretIsMidLine = function () {
    var pos = this.caretPosition();

    if ( pos == 0 ) {
        return 0;
    }

    var char_before = this.textarea.value.substr( pos - 1, 1 );
    if ( char_before == "\n" || char_before == "" ) {
        return 0;
    }
    else {
        return 1;
    }
};

Textarea.Text.prototype.moveCaretAfter = function (text) {
    var pos = this.textarea.value.lastIndexOf( text, this.caretPosition() );

    if ( ! pos ) {
        return;
    }

    this.moveCaret( ( pos - this.caretPosition() ) + 1 );
};
