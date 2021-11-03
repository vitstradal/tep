var html2wiki_handlers = {
        b: '**%s**',
        strong: '**%s**',
        p: "%s\n\n" ,
        pre: "\n{{{\n%s\n}}}\n" ,
        h1: "= %s =\n\n",
        h2: "== %s ==\n\n",
        h3: "=== %s ===\n\n",
        h4: "==== %s ====\n\n",
        h5: "===== %s =====\n\n",
        h6: "====== %s ======\n\n",
        i: "''%s''",
        sub: ",,%s,,",
        sup: "^^%s^^",
        s: "~~%s~~",
        table: "{|\n%s|}\n",
        tr: "%s|-\n",
        th: "! %s\n",
        td: "| %s\n",
        code: function(s, node) {
                if( node.parentNode.localName == 'pre' ) {
                        return s
                }
                return '`' + s + '`'
        },
        ul: function (s, node) { return _space_af_ulol(s, node) },
        ol: function (s, node) { return _space_af_ulol(s, node) },
        li: function (s, node) {

                var indent = "  ".repeat( _count_ulol(node) - 1  )
                var parTag = node.parentNode.localName
                if( parTag == 'ol' ) {
                  return "\n" + indent + '1. ' + s
                }
                return "\n" +  indent + '* ' + s
        },
        a: function (s, node) {
          return '[' + node.attributes.href.value + '|' + s + ']'
        },
        img: function (s, node) {
          console.log('img', node)
          return '[[Image(' + node.attributes.src.value + ')]]'
        },
}

function _space_af_ulol(s, node) {
        if( _count_ulol(node) > 1 ) {
                return s
        }
        return s + "\n"
}

function _count_ulol(node, tagName) {
        let count = 0
        while( node.parentNode != null ) {
                if ( node.localName == 'ol' || node.localName == 'ul'  ) {
                        count++
                }
                node = node.parentNode;
        }
        return count;
}

function _has_parent(node, tagName) {
        while( node.parentNode != null ) {
                if ( node.localName == tagName ) {
                        return true;
                }
                node = node.parentNode;
        }
        return false;
}

function _tracwiki_walk(node) {
        if ( ! node.childNodes ) {
                return ''
        }
        if ( node.childNodes.length == 0   ) {
                var txt = node.textContent
                return txt
        }
        var ret = []
        for (var idx in node.childNodes ) {
                ret.push(_tracwiki_walk(node.childNodes[idx]))
        }
        var tag = node.localName
        var content = ret.join('')
        var handler = html2wiki_handlers[tag]
        if( typeof handler == 'function' ) {
                return handler(content, node)
        }
        else if( typeof handler == 'string' ) {
                return handler.replace( '%s', content)
        }
        return _esc(content);
}

function _esc(str) {
        return str.replace( "\xa0", '')
}

function html2tracwiki( html ) {
        var parser =new DOMParser()
        var html_parsed = parser.parseFromString(html, 'text/html')
        return _tracwiki_walk(html_parsed.children[0])
}
