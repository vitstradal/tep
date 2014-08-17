ace.define("ace/mode/tracwiki_highlight_rules",["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"], function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;

var TracwikiHighlightRules = function() {
    this.$rules = {
        "start" : [
            {   // heading
                token : "markup.heading",
                regex : "^==*",
                next  : "heading"
            },
            {   // strike
                token : "string",
                regex : /~~[^~]*~~/,
            },
            {   // inline pre
                token : "string",
                regex : /`[^`]*`/,
            },
            {   //sub
                token : "string",
                regex : /,,[^,]*,,/,
            },
            {   // inline math
                token : "string",
                regex : /\$[^$]*\$/,
            },
            {   // sup
                token : "string",
                regex : /\^[^^]*\^/,
            },
            {   // italic
                token : "string",
                regex : /''[^']*''/,
            },
            {   // bold
                token : "string",
                regex : /\*\*[^*]*\*\*/,
            },
            {   //table
                token : "string",
                regex : /^\|\|.+/
            },
            {   // li ul
                token : "keyword",
                regex : /^\s*[\*#].*/
            },
            {   //pre
                token : "keyword",
                regex : /^\{\{\{$/,
                next : 'pre'
            },
            {   // text
                token : "text",
                regex : "."
            }
        ],
        "pre" : [
            {
                token : "keyword",
                regex : /^\}\}\}/,
                next  : "start"
            },
            {
                token : "keyword",
                regex : /.*/,
            },
        ],
        "heading" : [
            {
                token : "markup.heading",
                regex : "==*",
                next  : "start"
            },
            {
                token : "markup.heading",
                regex : "[^=]+"
            },
            {
                token : "text",
                regex : ".*"
            },
        ],
    };
};

oop.inherits(TracwikiHighlightRules, TextHighlightRules);

exports.TracwikiHighlightRules = TracwikiHighlightRules;

});

ace.define("ace/mode/matching_brace_outdent",["require","exports","module","ace/range"], function(require, exports, module) {
"use strict";

var Range = require("../range").Range;

var MatchingBraceOutdent = function() {};

(function() {

    this.checkOutdent = function(line, input) {
        if (! /^\s+$/.test(line))
            return false;

        return /^\s*\}/.test(input);
    };

    this.autoOutdent = function(doc, row) {
        var line = doc.getLine(row);
        var match = line.match(/^(\s*\})/);

        if (!match) return 0;

        var column = match[1].length;
        var openBracePos = doc.findMatchingBracket({row: row, column: column});

        if (!openBracePos || openBracePos.row == row) return 0;

        var indent = this.$getIndent(doc.getLine(openBracePos.row));
        doc.replace(new Range(row, 0, row, column-1), indent);
    };

    this.$getIndent = function(line) {
        return line.match(/^\s*/)[0];
    };

}).call(MatchingBraceOutdent.prototype);

exports.MatchingBraceOutdent = MatchingBraceOutdent;
});

ace.define("ace/mode/tracwiki",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/tracwiki_highlight_rules","ace/mode/matching_brace_outdent"], function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var TextMode = require("./text").Mode;
var TracwikiHighlightRules = require("./tracwiki_highlight_rules").TracwikiHighlightRules;
var MatchingBraceOutdent = require("./matching_brace_outdent").MatchingBraceOutdent;

var Mode = function() {
    this.HighlightRules = TracwikiHighlightRules;
    this.$outdent = new MatchingBraceOutdent();
};
oop.inherits(Mode, TextMode);

(function() {
    this.getNextLineIndent = function(state, line, tab) {
        if (state == "intag")
            return tab;
        
        return "";
    };

    this.checkOutdent = function(state, line, input) {
        return this.$outdent.checkOutdent(line, input);
    };

    this.autoOutdent = function(state, doc, row) {
        this.$outdent.autoOutdent(doc, row);
    };
    
    this.$id = "ace/mode/tracwiki";
}).call(Mode.prototype);

exports.Mode = Mode;

});
