function checkedBoolean(obj) {
  return obj.is(":checked")
}

function getFnc_equalToBoolean(val) {
  return function(obj) { return val.includes(obj.val()) }
}

function setToDefault(str, base) {
  form = document.forms[ base + '_form' ];
  element = form.elements[ base + '_' + str ];
  if (element && element.type == "checkbox") {
    element.checked = false;
  }
}

function enableConditioned(str, cond, base) {
  if (cond) {
    $('#' + str).show(400);
  } else {
    $('#' + str).hide();
    setToDefault(str, base);
  }
}

function colorConditioned(str, cond) {
  if (cond) {
    document.getElementById(str).style.backgroundColor = "#FFFFFF";
  } else {
    document.getElementById(str).style.backgroundColor = "#F8F8F0";	
  }
}

function _executeIf(to_check, to_enable, test_fnc, act_fnc, base) {
  return function() {
    var condition = false;
    for(let idx in to_check) {
      condition |= test_fnc($('#' + to_check[idx]));
    }
    for(let idx in to_enable) {
      act_fnc(to_enable[idx], condition, base);
      $('#event_' + to_enable[idx]).change();
    }
  }
}

function toArray(inp) {
  return Array.isArray(inp) ? inp : [ inp ];
}

function executeIf(to_check, to_enable, checked=true, val="", act_fnc, base) {
  to_check = toArray(to_check);
  to_enable = toArray(to_enable);
  if(checked) {
    test_fnc = checkedBoolean;
  } else {
    val = toArray(val);
    test_fnc = getFnc_equalToBoolean(val);
  }
  for(let idx in to_check) {
    $('#' + to_check[idx]).change(_executeIf(to_check, to_enable, test_fnc, act_fnc, base));
    $('#' + to_check[idx]).change();
  }
}

function showIf(to_check, to_enable, checked=true, val="", base="event") {
  executeIf(to_check, to_enable, checked=checked, val=val, enableConditioned, base);
}

function colorIf(to_check, to_enable, checked=true, val="", base="participant") {
  executeIf(to_check, to_enable, checked=checked, val=val, colorConditioned, base);
}

jQuery(function($) {
	if (!(document.forms['event_form'] === undefined)) {

        $('#event_event_category').change(function (){
                var val = $(this).val()
		multi_day_categories = JSON.parse(document.getElementById("multi_day_categories").dataset.codes)
                $('#event_start').hide()
                $('#event_end').hide()
                if( multi_day_categories.includes(val) )  {
                  $('#event_start').show(400)
                  $('#event_end').show(400)
                  document.getElementById('event_start_label').innerHTML = "Začátek akce"
                }
                else {
                  $('#event_start').show(400)
		  document.getElementById('event_start_label').innerHTML = "Datum konání akce"
                }
        });

	if (JSON.parse(document.getElementById("act_participant_is_edit").dataset.value) == false) {
	$('#event_event_category').change(function (){
                var val = $(this).val()
                full_act_categories = JSON.parse(document.getElementById("full_act_categories").dataset.codes)
                form = document.forms[ 'event_form' ];
                element = form.elements[ 'event_activation_needed' ];
                if( full_act_categories.includes(val) )  {
                  element.value = "full";
                }
                else {
                  element.value = "light";
                }
        });
	}

	showIf('event_event_category', 'event_visible_all_div', false, JSON.parse(document.getElementById("visibility_info_categories").dataset.ev));

  showIf('event_event_category', 'event_visible_restricted_div', false, JSON.parse(document.getElementById("visibility_info_categories").dataset.user));

	showIf('event_event_category', ['max_participants', 'limit_num_participants', 'uninvited_participants_dont_see', 'enable_only_specific_participants', 'enable_only_specific_substitutes', 'uninvited_organisers_dont_see', 'enable_only_specific_organisers'], false, JSON.parse(document.getElementById("restrictions_electible_categories").dataset.codes));

	showIf('event_event_category', 'spec_mass', false, JSON.parse(document.getElementById("mass_spec_electible_categories").dataset.codes));
  
  $('#event_event_category').change();

	showIf('event_limit_num_participants', 'max_participants');

	showIf(['event_enable_only_specific_participants', 'event_enable_only_specific_substitutes'], 'uninvited_participants_dont_see');

	showIf('event_enable_only_specific_organisers', 'uninvited_organisers_dont_see');

	showIf('event_spec_place', 'spec_place_detail');
	}

	if (!(document.forms['participant_form'] === undefined)) {
	colorIf('participant_activated', ['participant_sex', 'participant_birth', 'participant_address', 'participant_eating_habits', 'participant_health_problems', 'participant_birth_number', 'participant_health_insurance'], false, "full", "participant");
	}

  if (document.getElementById("act_display_participants")) {
    var url = "https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js";
    $.getScript( url, function() {
      const table = new DataTable('#act_display_participants', {
          paging: false,
          searching: false,
          info: false,
          scrollY: false,
          scrollX: false
      });
      
      document.querySelectorAll('a.toggle-vis').forEach((el) => {
          el.addEventListener('click', function (e) {
              e.preventDefault();
      
              let columnIdx = e.target.getAttribute('data-column');
              let column = table.column(columnIdx);
      
              // Toggle the visibility
              column.visible(!column.visible());
          });
      });
    });
  }
});
