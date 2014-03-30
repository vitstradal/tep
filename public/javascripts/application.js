// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

jQuery(document).ready(function($) {


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
					{ "sType": "numstr", "aTargets": [ 20, 21, 22 ] },
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
});

function focus_down(element, delta = 1) {
    var td  = $(element).closest('td');
    var tr  = $(td).closest('tr');
}

