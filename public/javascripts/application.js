// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

//$(document).ready(function () { 
//alert("ble");
//});

jQuery(document).ready(function($) {
        $('#school_id').change(function (){ 
                if('jina' == $(this).val()) {
                  $('#school_div').show(400);
                }
                else {
                  $('#school_div').hide(400);
                }
        }).change();
        $('.ctrl-enter-submit').keydown(function (e) {
                if (e.ctrlKey && e.keyCode == 13) {
                  $(this).closest('form').submit();
                }
        });
});


