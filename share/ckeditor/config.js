CKEDITOR.editorConfig = function( config )
{
    config.toolbar_Silki =
        [ [ "Bold", "Italic" ],
          [ "H2", "H3", "H4", "-", "Pre" ],
          [ "NumberedList", "BulletedList", "-", "Outdent", "Indent", "Blockquote" ],
          [ "Link", "Unlink" ],
          [ "Image", "Table", "HorizontalRule", "SpecialChar" ],
          [ "Undo", "Redo", "Maximize" ] ];

    config.toolbar = "Silki";

    config.skin = "Silki";

    config.linkShowTargetTab = false;
    config.linkShowAdvancedTab = false;
};

