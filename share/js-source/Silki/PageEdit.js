JSAN.use('DOM.Events');
JSAN.use('DOM.Utils');
JSAN.use('Textarea');

if ( typeof Silki == "undefined" ) {
    Silki = {};
}

if ( typeof Silki.PageEdit == "undefined" ) {
    Silki.PageEdit = {};
}

Silki.PageEdit.instrumentForm = function () {
    var form = $("form-and-preview");

    if ( ! form ) {
        return;
    }

    var textarea = new Textarea ( $("page-content") );

    for ( var i = 0; i < Silki.PageEdit._Buttons.length; i++ ) {
        var button_def = Silki.PageEdit._Buttons[i];

        var button = $( button_def[0] + "-button" );

        if ( ! button ) {
            continue;
        }

        if ( typeof button_def[1] == "function" ) {
            Silki.PageEdit._instrumentButton( button, button_def[1], textarea );
        }
        else {
            var open = button_def[1];
            var close = button_def[2];

            var func = Silki.PageEdit._makeTagTextFunction( open, close, textarea );

            Silki.PageEdit._instrumentButton( button, func );
        }
    }

};

Silki.PageEdit._makeTagTextFunction = function ( open, close, textarea ) {
    var func = function () {
        var text = textarea.selectedText();

        result = text.match( /^(\s+)?(.+?)(\s+)?$/ );

        var new_text;
        if ( result && result[0] ) {
            new_text =
                ( typeof result[1] != "undefined" ? result[1] : "" )
                + open + result[2] + close +
                ( typeof result[3] != "undefined" ? result[3] : "" );
        }
        else {
            new_text = open + text + close;
        }

        textarea.replaceSelectedText(new_text);

        if ( ! text.length ) {
            textarea.moveCaret( close.length * -1 );
        }
    };

    return func;
};

Silki.PageEdit._instrumentButton = function ( button, func, textarea ) {
    var on_click = function () {
        /* get selected text */
        func(textarea);
    };

    DOM.Events.addListener( button, "click", on_click );
};

Silki.PageEdit._insertBulletList = function (textarea) {
    Silki.PageEdit._insertBullet( textarea, "*" );
};

Silki.PageEdit._insertNumberList = function (textarea) {
    Silki.PageEdit._insertBullet( textarea, "1." );
};

Silki.PageEdit._insertBullet = function (textarea, bullet) {
    var insert;
    var old_pos;

    if ( textarea.caretIsMidLine() ) {
        insert = bullet + " ";
        old_pos = textarea.caretPosition();
    }
    else {
        insert = bullet + " \n\n";
    }

    if ( ! textarea.previousLine().match(/^\n?$/) ) {
        insert = "\n" + insert;
    }

    textarea.moveToBeginningOfLine();

    textarea.replaceSelectedText(insert);

    if (old_pos) {
        textarea.moveCaret( ( old_pos - textarea.caretPosition() ) + insert.length );
    }
    else {
        textarea.moveCaret(-2);
    }
};

Silki.PageEdit._makeInsertHeaderFunction = function (header) {
    var func = function (textarea) {
        var old_pos;

        var insert = header + " ";

        if ( textarea.caretIsMidLine() ) {
            old_pos = textarea.caretPosition();
        }
        else {
            insert = insert + "\n\n";
        }

        textarea.moveToBeginningOfLine();

        textarea.replaceSelectedText(insert);

        if (old_pos) {
            textarea.moveCaret( ( old_pos - textarea.caretPosition() ) + insert.length );
        }
        else {
            textarea.moveCaret(-2);
        }
    };

    return func;
};

Silki.PageEdit._Buttons = [ [ "h2", Silki.PageEdit._makeInsertHeaderFunction('##') ],
                            [ "h3", Silki.PageEdit._makeInsertHeaderFunction('###') ],
                            [ "h4", Silki.PageEdit._makeInsertHeaderFunction('####') ],
                            [ "bold", "**", "**" ],
                            [ "italic", "*", "*" ],
                            [ "bullet-list", Silki.PageEdit._insertBulletList ],
                            [ "number-list", Silki.PageEdit._insertNumberList ]
                          ];
