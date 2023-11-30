function checkedBoolean(obj) {
  return obj.is(":checked")
}

function getFnc_equalToBoolean(val) {
  return function(obj) { return val.includes(obj.val()) }
}

function setToDefault(str) {
  form = document.forms['event_form'];
  element = form.elements['event_' + str];
  if (element && element.type == "checkbox") {
    element.checked = false;
  }
}

function enableIf(to_check, to_enable, test_fnc) {
  return function() {
    var condition = false;
    for(let idx in to_check) {
      condition |= test_fnc($('#' + to_check[idx]));
    }
    if(condition) {
      for(let idx in to_enable) {
        $('#' + to_enable[idx]).show(400);
      }
    } else {
      for(let idx in to_enable) {
        $('#' + to_enable[idx]).hide();
        setToDefault(to_enable[idx]);
      }
    }
  }
}

function toArray(inp) {
  return Array.isArray(inp) ? inp : [ inp ];
}

function showIf(to_check, to_enable, checked=true, val="") {
  to_check = toArray(to_check);
  to_enable = toArray(to_enable);
  if(checked) {
    fnc = checkedBoolean;
  } else {
    val = toArray(val);
    fnc = getFnc_equalToBoolean(val);
  }
  for(let idx in to_check) {
    $('#' + to_check[idx]).change(enableIf(to_check, to_enable, fnc));
    $('#' + to_check[idx]).change();
  }
}

jQuery(document).ready(function($) {
        $('#event_event_category').change(function (){
                var val = $(this).val()
		multi_day_categories = JSON.parse(document.getElementById("multi_day_categories").dataset.categories)
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

	showIf('event_event_category', 'event_visible_all_div', false, JSON.parse(document.getElementById("visibility_info_categories").dataset.ev))

        showIf('event_event_category', 'event_visible_restricted_div', false, JSON.parse(document.getElementById("visibility_info_categories").dataset.user))

	showIf('event_event_category', ['limit_num_participants', 'max_participants', 'enable_only_specific_participants', 'enable_only_specific_substitutes', 'uninvited_participants_dont_see', 'enable_only_specific_organisers', 'uninvited_organisers_dont_see'], false, JSON.parse(document.getElementById("restrictions_electible_categories").dataset.codes))

	showIf('event_event_category', 'spec_mass', JSON.parse(document.getElementById("mass_spec_electible_categories").dataset.codes))
});
