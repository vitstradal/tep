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
        mark: function(s, node) {
                if( node.className == 'marker-blue' ) {
                	return "\n$$ " + s + " $$";
                }
                if( node.className == 'marker-green' ) {
                	return '$' + s + '$';
                }
                return s;
        },
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
                  return "\n" + indent + '' + _count_li(node) + '. ' + s
                }
                return "\n" +  indent + '* ' + s
        },
        a: function (s, node) {
          return '[' + node.attributes.href.value + '|' + s + ']'
        },
        img: function (s, node) {
          //console.log('img', node)
          return '[[Image(' + _strip_scheme_and_server(node.attributes.src.value) + ')]]'
        },
}

function _strip_scheme_and_server(image_url) {
        return image_url.replace(/^https?:\/\/[^/]*/, '')
}
function _count_li( node ) {
        let count = 1
        while( node.previousElementSibling != null ) {
                if ( node.localName == 'li' ) {
                        count++
                }
                node = node.previousElementSibling;
        }
        return count;
}

function _space_af_ulol(s, node) {
        if( _count_ulol(node) > 1 ) {
                return s
        }
        return s + "\n\n"
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
        var tag = node.localName
        if( tag == undefined ) {
                return node.textContent
        }
        var ret = []
        for (var idx in node.childNodes ) {
                var child_txt =_tracwiki_walk(node.childNodes[idx])
                ret.push(child_txt)
        }
        var content = ret.join('')
        //console.log("walk:", tag, content)
        var handler = html2wiki_handlers[tag]
        if( typeof handler == 'function' ) {
                return handler(content, node)
        }
        else if( typeof handler == 'string' ) {
                // BEVARE replace has special character $
                return handler.replace( '%s', function() { return content} )
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
