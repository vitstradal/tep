// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

var foto_cat = '';
//var anketa_states = [ 'fa-square-o', 'fa-check-square-o', 'fa-plus-square-o', 'fa-minus-square-o',  ];
var anketa_states = [ 'fa-circle-o', 'fa-smile-o', 'fa-meh-o', 'fa-frown-o',  ];
var anketa_td_class = [ 'anketa-nic', 'anketa-yes', 'anketa-maybe', 'anketa-no',  ];
var anketa_txt =    [ ' ', 'y', '?', 'n' ];

jQuery(document).ready(function($) {
        //hack: menu na spodni kosticku
        $('.secret-menu-toggler').click(function (ev) {
          ev.preventDefault();
	  $('#sidebar').toggleClass('hide');
	  $('#main-content-id').toggleClass('main-content');
        });

        // anketa zvyrazneni
        $('div.anketa').each(function (ii, div) {
           var pos = parseInt($(this).data('lineno')||0) + 2;
           var ver = $(this).data('version');
           var stat = {};
           var $table = $(div).next();
           console.log("csrf", $('meta[name=csrf-token]').attr('content'));
           $table.find('td').first().each(function (i,td) {
             $(this).addClass('hand');
             $(td).prepend( $('<span class="fa fa-lg fa-plus-square-o">&nbsp;</span>'));
             $(this).click(function () {

               var $tr = $table.find('.edit-row');
               if( $tr.length > 0  ) {
                 $tr.toggle();
                 return;
               }

               $tr = $('<tr class="edit-row">');
               var user = ($('.label-user').text() || "anon").replace(/@.*/, '').replace(/ /, '');

               $tr.append($('<td><input type="text" value="' + uc_first(user) + '"/></td>'));
               for (var k in stat ) {
                 var $quad =$("<span class='fa fa-circle-o'></span>");
                 var $td = $('<td data-state="0">').append($quad);
                 $td.click(function (but) {
                   var $this = $(this);
                   var state = (parseInt($this.data('state')||0) + 1)%4;
                   $this.find('span').attr('class', 'hand fa ' + anketa_states[state]);
                   $this.data('state', state);
                   $this.attr('class', anketa_td_class[state]);
                 });
                 $tr.append($td);
               }

               var $csrf = $('<input type="hidden" name="authenticity_token">').val($('meta[name=csrf-token]').attr('content'));
               var $pos = $('<input type="hidden" name="pos">').val(pos);
               var $ver = $('<input type="hidden" name="version">').val(ver);
               var $text = $('<input type="hidden" name="text">');
               var $form = $('<form method="POST">').append($csrf).append($pos).append($text).append($ver);
               $form.append( $('<button type="submit" class="btn btn-danger">save</button>'));
               $form.submit(function () {
                 var $tr = $(this).closest('tr');
                 var row = '|| ' + ($tr.find('input').val() || '???' );
                 $tr.find('td[data-state]').each(function () { row +=  ' || ' + anketa_txt[parseInt($(this).data('state')||0)] });
                 row += " ||\n";
                 $text.val(row);
                 console.log('row:', row);
               });
               $tr.append($('<td>').append($form));
               $table.find('tr').first().after($tr);
              }); /* click */
           });
           $table.find('td').each(function (i,td) {
             var $td = $(td);
             var txt = $td.text();
             var c =  $td.index();
             var r =  $td.parent().index();
             var dostat = true;
             switch(txt) {
               case 'y': $td.addClass('anketa-yes'); break;
               case 'n': $td.addClass('anketa-no'); break;
               case '?': $td.addClass('anketa-maybe'); break;
               default:  dostat = false;
             }
             if( dostat ) {
                     stat[c] = stat[c] || {};
                     stat[c][txt] = stat[c][txt] || 0;
                     stat[c][txt]++;
             }
          });
          var tab = [];
          //console.log("stat", stat);
          var $tr = $('<tr>').append('<td>&sum;</td>');
          for (var k in stat ) {
            var ret ='';
            var ry = stat[k]['y'] || 0;
            var rn = stat[k]['n'] || 0;
            var rm = stat[k]['?'] || 0;
            //ret = "<span class='anketa-yes'>" + ry + "</span>/<span class='anketa-maybe'>" + rm + "</span>/<span class='anketa-no'>" + rn + "</span>";
            ret = ry + "/" + rm + "/" + rn;
            var $td = $('<td>');
            $td.html(ret);
            $tr.append($td);
            tab[k] = ret;
          }
          $table.append($tr);
          console.log('tab', tab);
        });


        $('.ace-file-input').ace_file_input()
                            .on('change', function () {
                                    $(this).closest('form').submit();
                             });

        // data tables 
	jQuery.extend( jQuery.fn.dataTableExt.oSort, {
	    "locale-pre": function ( a ) {
	        return a.replace(/<[^>]*>/,'');
	    },
	    "locale-asc": function ( a, b ) {
		//console.log("asc:", a, b, a.localeCompare(b));
		return a.localeCompare(b) < 0 ? -1 : 1;
	    },
	    "locale-desc": function ( a, b ) {
		//console.log("desc:", a, b, a.localeCompare(b));
		return b.localeCompare(a) < 0 ? -1 : 1;
	    },
            "numstr-pre": function ( a ) { return parseInt(a); },
            "numstr-asc":  function ( a, b ) { return a - b; },
            "numstr-desc": function ( a, b ) { return b - a; },
	} );

/*
 */
        $('.datatable').dataTable({
                "bPaginate": false,
                "bLengthChange": false,
                "bFilter": false,
                "bInfo": false,
                "bAutoWidth": false,
		//"bSort": false,
		"aaSorting": [],
	        "aoColumnDefs": [
					{ "sType": "numeric", "aTargets": [ 0,  ] },
					{ "sType": "locale", "aTargets": [ 1 ] },
//					{ "sType": "numstr", "aTargets": [ 1 ] },
			        ],
        });
        /********************************************************
         * fotky
         */
        $('button[data-foto-dir]').click(function (ev) {
          var src = $(this).closest('.modal').find('img').attr('src');
          var foto = $('a[href="'+src+'"]').closest('.foto');

          var dir = $(this).data('foto-dir');

          var cat = $('.fotofilter.label-success').attr('id');
          cat = cat === null || cat == 'ff-all' ? null : '.' + cat;
          //console.log('cat', cat);

          var next =( dir ==  'next' ) ?  foto.nextAll(cat):
                                          foto.prevAll(cat);
          next.first().find('img').click();
        });

        $('#foto-modal').on('hide.bs.modal', function () { set_hash(foto_cat); });

        $('.foto img').click(function (ev) {
           ev.preventDefault();
           var foto = $(this).closest('.foto');
           var bigimg = $(this).closest('a').attr('href');
           var title = $(this).closest('.foto').find('span').text();
           $('#foto-modal').modal('show');
           $('#foto-modal').height(  $(window).height() );
           var wh = $(window).height() - 10;
           $('#foto-modal .modal-content').height(wh);
           var hh = $('#foto-modal .modal-title').height();
           console.log('h', wh , hh);
           $('#foto-modal img').attr('src', bigimg)
                            .css('height', wh - 50)
                            .css('width', 'auto');
           $('#foto-modal a').attr('href', bigimg);
           $('#foto-modal .modal-title').text(title);

           var cat = $('.fotofilter.label-success').attr('id');
           cat = cat === null || cat == 'ff-all' ? '' :  cat.substr(3);

           set_hash(cat, foto);
        });
        $('.fotofilter').click(function (){
            $(".fotofilter").removeClass('label-success');
            $(this).addClass('label-success');
            var id = $(this).attr('id');
            //console.log("select", id);
            if( id == 'ff-all' ) {
              $("span.foto").show();
              set_hash('');
              return;
            }
            $("span.foto").each(function (i, el) {
              if( $(el).hasClass(id) ) {
                $(el).show();
              } else {
                $(el).hide();
              }
            });
            set_hash(id.substr(3));
        });
        $('.fotos').first().each( function () {
           var hash = get_hash();
           var filter = hash[0];
           var imgid = hash[1];
           //console.log("hash:", filter, imgid);
           if( filter && filter != '' ) {
             //console.log("click:", '#ff-' + filter);
             $('#ff-' +  filter ).click();
           }
           if( imgid )  {
              $('[id="' + imgid + '"]').find('img').click();
           }
        });


        $('#school_id').change(function (){
                if('jina' == $(this).val()) {
                  $('#school_div').show(400);
                }
                else {
                  $('#school_div').hide(400);
                }
        });

        var sch = $('#school_id');
        //console.log('schval:', sch.val());
        if( sch.length == 1 && sch.val() != 'jina' ) {
          $('#school_div').hide();
        }

        // ctrl-enter submit formu in textarea
        $('.ctrl-enter-submit').keydown(function (e) {
                if (e.ctrlKey && e.keyCode == 13) {
                  $(this).closest('form').submit();
                }
        });
        $('form[id^=edit_sosna_solution]').submit(function(){
          var isOk = true;
          $('input[type=file][max-size]', this).each(function(){
            if(typeof this.files[0] !== 'undefined'){
                var maxSize = parseInt($(this).attr('max-size'),10);
                var f = this.files[0];
                var size = f.size || f.fileSize;
                if( size === undefined ) {
                  return;
                }
                var maxSizeMB = parseInt(maxSize/1000/1000);
                isOk = maxSize > size;
                if( ! isOk ) {
                  alert('Příliš velký soubor (>' + maxSizeMB + ' MB)');
                }
            }
            return isOk;
        });
    });

        /* nojs-in:  show when no js, so hide when js enabled */
        $('.nojs-in').removeClass('nojs-in');

        /* when js enabled, move  */
        $('div[data-move-to]').each(function (idx, el) { $(el).prependTo($(el).data('move-to')); });
        $('button[data-submit-form]').click(function () {
                $($(this).data('submit-form')).submit();
        });
        $('.ace-input-file').ace_file_input({icon_remove: null, style: false});


       // fakecrypted emails
       $('.mailcrypt').click(function () {
         var me = $(this);
         var email = fakedecrypt(me.attr('id'));
         var a= $('<a>');
         a.text(email);
         a.addClass('mailcrypt');
         a.attr('href', "mailto:" + email);
         me.after(a);
         me.hide();
       });

      // https://gist.github.com/duncansmart/5267653
      // turn textarea into ace-ecitor
      init_icons();
      $('textarea.aceeditor').each(function () {

                var $textarea = $(this);
                _init_textarea_with_ace($textarea);
      });

});

/* f otogal */
function set_hash(cat, img_el)
{
   foto_cat = cat;
   var hash = cat || '';

   if( img_el )  {
       //scroll to image
       $('html, body').scrollTop( img_el.offset().top );
       hash +=  ':' + img_el.attr('id');
   }
   window.location.hash = hash;
}


function get_hash()
{
   var hash = window.location.hash.substr(1).split(':');
   return hash; 
}

/*************************************
 * ace-editor support functions
 */

function editor_tool_button_switch($el, editor, form)
{
  var on = $el.is(':checked');
  var action = $el.data('edit');
  //console.log("editor_tool_button_switch");
  switch(action) {
  case 'vi':
     var kb = on ? 'ace/keyboard/vim' : '';
     editor.setKeyboardHandler(kb);
     editor.focus();
     ace.data.set('vi', on ? 'on' : 'off' );
     break;
  }
}

function editor_tool_button_click($el, editor, form)
{
  editor_tool_action($el.data('edit'), editor, form);
}

function editor_tool_action(action, editor, form)
{
  switch(action) {
  case 'link':    return editor_wrap(editor, '[[', ']]');
  case 'image':   return editor_wrap(editor, '[[Image(', ')]]');
  case 'bold':    return editor_wrap(editor, '**', '**');
  case 'italic':  return editor_wrap(editor, "''", "''");
  case 'strike':  return editor_wrap(editor, "~~", "~~");
  case 'comment': return editor_wrap(editor, "{{# ", "}}");
  case 'sup':     return editor_wrap(editor, "^", "^");
  case 'sub':     return editor_wrap(editor, ",,", ",,");
  case 'code':    return editor_wrap(editor, "`", "`");
  case 'math':    return editor_wrap(editor, "$", "$");
  case 'dmath':   return editor_wrap(editor, "\n$$", "$$\n");
  case 'h1':      return editor_wrap(editor, '=', '=');
  case 'h2':      return editor_wrap(editor, '==', '===');
  case 'h3':      return editor_wrap(editor, '===', '===');
  case 'pre':     return editor_wrap(editor, "\n{{{\n", "\n}}}\n");
  case 'ul':      return editor_wrap(editor, "* ");
  case 'ol':      return editor_wrap(editor, "1. ");
  case 'img':     return editor_wrap(editor, "[[Image(", ")]]");
  case 'save':    return editor_save(editor, form, false);
  case 'save-stay':return editor_save(editor, form, true);
  case 'cancel':  return editor_cancel(editor, form);
  case 'preview': return editor_preview(editor, form);
  case 'help':    return editor_show_url(editor, form.find('[data-help-url]').data('help-url'));
  case 'icons':   return editor_show_url(editor, form.find('[data-icons-url]').data('icons-url')); 
  default:
          return editor_wrap(editor, '[[', ']]');
  }
}

function init_icons(editor) {
       //console.log("init_icoshow");
       if( editor ) { 
               $('.icoshow').click(function () {
                 var c = $(this).find('span').text();
                 //console.log("icoshow", c);
                 editor_wrap(editor, '{{ico ' + c + '}}');
               });
       }
       else {

               $('.icoshow').click(function () {
                 //console.log("icoshow");
                 $(this).find('span').removeClass('hide');
               });
       }
}

function editor_cancel(editor, form)
{
  //console.log('editor cancel');
  $(form).find('.editorcancel').each(function (i, el) { 
    //console.log('editor cancel');
    window.location =  $(el).attr('href');
  });
}

function editor_save(editor, form, stay)
{
  if( stay) {
    $(form).find('[name=edit]').val('1');
    save_cursor(editor, form);
  }
  form.submit();
}

function save_cursor(editor,form) {
  var pos = editor.getCursorPosition();
  //console.log("save_cursor", pos);
  $(form).find('input[name=cursor]').val(pos.row + ":" + (pos.column ||0));
}

function editor_show_url(editor, url)
{
   //console.log("show_url", url);
   if( ! url ) { 
     //console.log("no url: no way");
     return;
   }
   $.get(
     url,
     function (data, textStatus, jqXHR) {
       $('#preview-div').html(data['html']||'error');
       init_icons(editor);
     }
   );
}

function editor_preview(editor, form)
{

   var action = form.attr('action');
   var wiki = editor.getSession().getValue();
   //console.log("action", action);
   $.ajax({
     url: action,
     type: 'POST',
     headers: {
       'X-Transaction': 'POST Example',
       'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
     },
     data: { preview: wiki},
     success: function (data, textStatus, jqXHR) {
       //console.log("data", data, "status", textStatus, jqXHR);
       $('#preview-div').html(data['html']||'error');
     }
   });
}

function editor_wrap(editor, pre, post) {
  var txt = editor.session.getTextRange(editor.getSelectionRange());
  post = post ||'';
  pre = pre ||'';
  editor.insert( pre +txt+ post);
  if( post.length) {
    editor.navigateLeft(post.length);
  }
  editor.focus();
}


/**********************************************
 * email anitspam show
 */
function fakedecrypt(x)
{
  var f = 'abcdefghijklmnopqrstuvwxyz512';
  var t = 'pqrstuvwxyzabcdefghijklmno@.-';
  var ret = '';
  for(var i=0; i < x.length; i++) {
    ret += t[f.indexOf(x[i])] || x[i];
  }
  return ret;

}

function uc_first(s) {
    return s.charAt(0).toUpperCase() + s.slice(1);
}


function _init_textarea_with_ace($textarea) {

        //var mode = textarea.data('editor');
        //var mode = 'tracwiki';
        var mode;
        mode = 'tracwiki';
        var cont = $textarea.closest('.textarea-container');

        var editDiv = $('<div>', {
                position: 'absolute',
                width: cont.width(),
                height: cont.height(),
                'float': 'left',
                'class': cont.attr('class')
        }).insertBefore($textarea);


        //textarea.css('visibility', 'hidden');
        $textarea.css('display', 'none');


        var editor = ace.edit(editDiv[0]);
        editor.renderer.setShowGutter(false);
        editor.getSession().setValue($textarea.val());
        editor.getSession().setMode("ace/mode/" + mode);
        editor.getSession().setUseWrapMode(true);

        //editor.setTheme("ace/theme/twilight");
        //ace.require("ace/ext/chromevox");

        editor.setTheme("ace/theme/tomorrow");
        editor.renderer.setShowGutter(true);
        //editor.renderer.setShowInvisibles(true);

        var form = $textarea.closest('form');

        editor.commands.bindKeys({
                        'ctrl-b':       function () { editor_tool_action('bold', editor, form ); },
                        'ctrl-i':       function () { editor_tool_action('italic', editor, form ); },
                        //'ctrl-$':     function () { editor_tool_action('math', editor, form ); },
                        'ctrl-escape':  function () { editor_cancel(editor, form);  },
                        'ctrl-enter':   function () { editor_save(editor, form, false);  },
                        'shift-enter':  function () { editor_save(editor, form, true);  },
                        'alt-enter':    function () { editor_preview(editor, form);  },
                        'ctrl-l':null,
                        'ctrl-t':null,
                        'ctrl-r':null,
                      })

        var pos_str = form.find('input[name=cursor]').val();
        if( pos_str ) {
           var pos = pos_str.split(/:/);
           console.log('cursor', pos);
           editor.moveCursorTo(pos[0], pos[1]);
         }

        // copy back to $textarea on form submit...
        form.submit(function () {
                var oo = editor.getSession().getValue();
                //console.log("oo.len:", oo.length, oo.substr(-10));
                $textarea.val(editor.getSession().getValue());
                //save_cursor(editor, form);
        });
        //.find('a[data-edit]').click(function () { editor_tool_button_click($textarea, editor); });
        $('a[data-edit]').click(function () {      editor_tool_button_click($(this), editor, form); });
        $('input[data-edit]').change(function () { editor_tool_button_switch($(this), editor, form); });
        $('input[data-edit]').each(function (i, el) { editor_tool_button_switch($(el), editor, form); });
}
