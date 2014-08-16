// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

jQuery(document).ready(function($) {


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
        $('.fotofilter').click(function (){
            $(".fotofilter").removeClass('label-success');
            $(this).addClass('label-success');
            var id = $(this).attr('id');
            console.log("select", id);
            if( id == 'ff-all' ) {
              $("span.foto").show();
              return;
            }
            $("span.foto").each(function (i, el) {
              if( $(el).hasClass(id) ) {
                $(el).show();
              } else {
                $(el).hide();
              }
            });
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
        if( sch.length == 1 && sch.val() == 'none' ) {
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
	$('.updownkeys input[type=text]').keydown(function (e) {
	   if (e.key == 'Down' ) {
	     focus_down(this, 1);
	   }
	   if (e.key == 'Up' ) {
	     focus_down(this, -1);
	   }
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
      //$('textarea[data-editor]').each(function () {
      init_icons();
      $('textarea').each(function () {
                var textarea = $(this);

                //var mode = textarea.data('editor');
                //var mode = 'tracwiki';
                var mode;
                mode = 'tracwiki';
                var cont = $(this).closest('.textarea-container');

                var editDiv = $('<div>', {
                        position: 'absolute',
                        width: cont.width(),
                        height: cont.height(),
                        'float': 'left',
                        'class': cont.attr('class')
                }).insertBefore(textarea);


                //textarea.css('visibility', 'hidden');
                textarea.css('display', 'none');


                var editor = ace.edit(editDiv[0]);
                editor.renderer.setShowGutter(false);
                editor.getSession().setValue(textarea.val());
                editor.getSession().setMode("ace/mode/" + mode);
                editor.getSession().setUseWrapMode(true);

                //editor.setTheme("ace/theme/twilight");
                //ace.require("ace/ext/chromevox");

                editor.setTheme("ace/theme/tomorrow");
                editor.renderer.setShowGutter(true);
                //editor.renderer.setShowInvisibles(true);

                var form = textarea.closest('form'); 
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

                // copy back to textarea on form submit...
                form.submit(function () {
                        textarea.val(editor.getSession().getValue());
                });
                //.find('a[data-edit]').click(function () { editor_tool_button_click(this, editor); });
                $('[data-edit]').click(function () { editor_tool_button_click(this, editor, form); });

     });
});

function editor_tool_button_click(el, editor, form)
{
  editor_tool_action($(el).data('edit'), editor, form);
}

function editor_tool_action(action, editor, form)
{
  switch(action) {
  case 'link':    return editor_wrap(editor, '[[', ']]');
  case 'image':   return editor_wrap(editor, '[[Image(', ')]]');
  case 'bold':    return editor_wrap(editor, '**', '**');
  case 'italic':  return editor_wrap(editor, "''", "''");
  case 'strike':  return editor_wrap(editor, "~~", "~~");
  case 'comment': return editor_wrap(editor, "{{#", "}}");
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
       console.log("init_icoshow");
       if( editor ) { 
               $('.icoshow').click(function () {
                 var c = $(this).find('span').text();
                 console.log("icoshow", c);
                 editor_wrap(editor, '{{ico ' + c + '}}');
               });
       }
       else {

               $('.icoshow').click(function () {
                 console.log("icoshow");
                 $(this).find('span').removeClass('hide');
               });
       }
}

function editor_cancel(editor, form)
{
  //console.log('editor cancel');
  $(form).find('.editorcancel').each(function (i, el) { 
    console.log('editor cancel');
    window.location =  $(el).attr('href');
  });
}

function editor_save(editor, form, stay)
{
  if( stay) {
    $(form).find('[name=edit]').val('1');
    console.log('save stay', $(form).find('[name=edit]').val());
  }
  form.submit();
}

function editor_show_url(editor, url)
{
   console.log("show_url", url);
   if( ! url ) { 
     console.log("no url: no way");
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
   console.log("action", action);
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


function focus_down(element, delta = 1) {
    var td  = $(element).closest('td');
    var tr  = $(td).closest('tr');
}
