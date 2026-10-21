/*
Language: Dart
Based on highlight.js 11.11.1 (Maxim Dikun), BSD-3-Clause.
Flutter widget names are included so a fence tagged dart or flutter colors them.
*/
if (window.hljs && !window.hljs.getLanguage("dart")) {
  window.hljs.registerLanguage("dart", function (hljs) {
    var SUBST = { className: "subst", variants: [{ begin: "\\$[A-Za-z0-9_]+" }] };
    var BRACED_SUBST = {
      className: "subst",
      variants: [{ begin: /\$\{/, end: /\}/ }],
      keywords: "true false null this is new super"
    };
    var NUMBER = {
      className: "number",
      relevance: 0,
      variants: [
        { match: /\b[0-9][0-9_]*(\.[0-9][0-9_]*)?([eE][+-]?[0-9][0-9_]*)?\b/ },
        { match: /\b0[xX][0-9A-Fa-f][0-9A-Fa-f_]*\b/ }
      ]
    };
    var STRING = {
      className: "string",
      variants: [
        { begin: "r'''", end: "'''" },
        { begin: "r\"\"\"", end: "\"\"\"" },
        { begin: "r'", end: "'", illegal: "\\n" },
        { begin: "r\"", end: "\"", illegal: "\\n" },
        { begin: "'''", end: "'''", contains: [hljs.BACKSLASH_ESCAPE, SUBST, BRACED_SUBST] },
        { begin: "\"\"\"", end: "\"\"\"", contains: [hljs.BACKSLASH_ESCAPE, SUBST, BRACED_SUBST] },
        { begin: "'", end: "'", illegal: "\\n", contains: [hljs.BACKSLASH_ESCAPE, SUBST, BRACED_SUBST] },
        { begin: "\"", end: "\"", illegal: "\\n", contains: [hljs.BACKSLASH_ESCAPE, SUBST, BRACED_SUBST] }
      ]
    };
    BRACED_SUBST.contains = [NUMBER, STRING];
    var CORE = [
      "Comparable", "DateTime", "Duration", "Function", "Iterable", "Iterator", "List", "Map",
      "Match", "Object", "Pattern", "RegExp", "Set", "Stopwatch", "String", "StringBuffer",
      "StringSink", "Symbol", "Type", "Uri", "bool", "double", "int", "num",
      "Never", "Null", "dynamic", "print"
    ];
    var FLUTTER = [
      "Widget", "StatelessWidget", "StatefulWidget", "State", "BuildContext", "Key", "GlobalKey",
      "Column", "Row", "Stack", "Text", "Container", "Scaffold", "Padding", "Center", "SizedBox",
      "Expanded", "Flexible", "ListView", "Icon", "Image", "AppBar", "EdgeInsets", "BoxDecoration",
      "BorderRadius", "Color", "Theme", "ThemeData", "MediaQuery", "Navigator", "Future", "Stream",
      "FutureBuilder", "StreamBuilder", "MainAxisAlignment", "CrossAxisAlignment", "TextStyle",
      "FontWeight", "Alignment", "TextButton", "ElevatedButton", "IconButton", "GestureDetector",
      "InkWell", "SingleChildScrollView", "SafeArea", "Material", "Card", "CircularProgressIndicator",
      "SnackBar", "AlertDialog", "AnimationController", "Tween", "ChangeNotifier", "ValueNotifier",
      "TextEditingController", "FocusNode", "Form", "TextFormField"
    ];
    var types = CORE.concat(FLUTTER);
    var keywords = {
      keyword: "abstract as assert async await base break case catch class const continue covariant default deferred do dynamic else enum export extends extension external factory false final finally for Function get hide if implements import in interface is late library mixin new null on operator part required rethrow return sealed set show static super switch sync this throw true try typedef var void when while with yield",
      built_in: types.concat(types.map(function (name) { return name + "?"; })).join(" "),
      $pattern: /[A-Za-z][A-Za-z0-9_]*\??/
    };
    return {
      name: "Dart",
      aliases: ["flutter"],
      keywords: keywords,
      contains: [
        STRING,
        hljs.COMMENT(/\/\*\*(?!\/)/, /\*\//, { relevance: 0 }),
        hljs.C_LINE_COMMENT_MODE,
        hljs.C_BLOCK_COMMENT_MODE,
        {
          className: "class",
          beginKeywords: "class interface",
          end: /\{/,
          excludeEnd: true,
          contains: [
            { beginKeywords: "extends implements" },
            hljs.UNDERSCORE_TITLE_MODE
          ]
        },
        NUMBER,
        { className: "meta", begin: "@[A-Za-z]+" }
      ]
    };
  });
}
