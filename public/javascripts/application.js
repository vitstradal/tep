// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

jQuery(document).ready(function($) {
        $('#school_id').change(function (){
                if('jina' == $(this).val()) {
                  $('#school_div').show(400);
                }
                else {
                  $('#school_div').hide(400);
                }
        }).change();

        // ctrl-enter submit formu in textarea
        $('.ctrl-enter-submit').keydown(function (e) {
                if (e.ctrlKey && e.keyCode == 13) {
                  $(this).closest('form').submit();
                }
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

