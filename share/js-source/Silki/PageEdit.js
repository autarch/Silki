JSAN.use('DOM.Events');
JSAN.use('DOM.Find');
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

        textarea.replaceOrInsertText(new_text);
    };

    return func;
}

Silki.PageEdit._instrumentButton = function ( button, func, textarea ) {
    var on_click = function () {
        /* get selected text */
        func(textarea);
    };

    DOM.Events.addListener( button, "click", on_click );
};

Silki.PageEdit._insertBulletList = function () {

};

Silki.PageEdit._insertNumberList = function () {

};

Silki.PageEdit._Buttons = [ [ "h2", "## ", "" ],
                            [ "h3", "### ", "" ],
                            [ "bold", "**", "**" ],
                            [ "italic", "*", "*" ],
                            [ "bullet-list", Silki.PageEdit._insertBulletList ],
                            [ "number-list", Silki.PageEdit._insertNumberList ]
                          ];
