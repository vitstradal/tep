function EnableIf(to_check, to_enable) {
  return function() {
    var val = false;
    for(let idx in to_check) {
      val |= $('#' + to_check[idx]).is(":checked");
    }
    if(val) {
      $('#' + to_enable).show(400);
    } else {
      $('#' + to_enable).hide();
    }
  }
}

function showIf(to_check, to_enable) {
  if(! Array.isArray(to_check)) {
     to_check = [ to_check ];
  }
  for(let idx in to_check) {
    $('#' + to_check[idx]).change(EnableIf(to_check, to_enable));
    $('#' + to_check[idx]).change();
  }
}

jQuery(document).ready(function($) {
        $('#event_event_category').change(function (){
                var val = $(this).val()
		multi_day_categories = document.getElementById("multi_day_categories").dataset.categories
                $('#event_start').hide()
                $('#event_end').hide()
                $('#event_date').hide()
                if( multi_day_categories.includes(val) )  {
                  $('#event_start').show(400)
                  $('#event_end').show(400)
                }
                else {
                  $('#event_date').show(400)
                }
        });

        $('#event_event_category').change();

	showIf('event_limit_num_participants', 'max_participants')

	showIf(['event_enable_only_specific_participants', 'event_enable_only_specific_substitutes'], 'uninvited_participants_dont_see');

	showIf('event_enable_only_specific_organisers', 'uninvited_organisers_dont_see');

	showIf('event_spec_place', 'spec_place_detail');
});
