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

  showIf('event_spec_place_return', 'spec_place_return_detail');

  if (document.getElementById("act_display_participants")) {
    var url = "https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js";
    $.getScript( url, function() {
      var show_org = true
      var show_sub = true
      var show_par = true
      var show_yes = true
      var show_no = true
      var show_maybe = true
      var show_columns = []
      const table = new DataTable('#act_display_participants', {
          paging: false,
          ordering: false,
          searching: false,
          info: false,
          scrollY: false,
          scrollX: true
      });

      $('span.toggle-vis').click( function (ev) {
          let element =  $(this)
          let columnIdx = element.data('column')
          let column = table.column(columnIdx)
          let column_visible = column.visible()
          element.toggleClass('bold', !column_visible)
          column.visible(!column_visible)
          update_url()
      });
      $('span.clear-vis').click( function (ev) {
         let count = table.columns().every( function(columnIdx) {
                console.log("columns index", columnIdx);
                let show = [0,2,3].includes(columnIdx)
                $('span.toggle-vis[data-column="' + columnIdx +'"]').toggleClass('bold', show)
                table.column(columnIdx).visible(show)
         });
         update_url()
      });

      $('span.toggle-org-vis').click( function (ev) {
         show_org = ! $(this).hasClass('bold');
         $(this).toggleClass('bold', show_org);
         redraw_table();
      });

      $('span.toggle-sub-vis').click( function (ev) {
         show_sub = ! $(this).hasClass('bold');
         $(this).toggleClass('bold', show_sub);
         redraw_table();
      });

      $('span.toggle-par-vis').click( function (ev) {
         show_par = ! $(this).hasClass('bold');
         $(this).toggleClass('bold', show_par);
         redraw_table();
      });

      $('span.toggle-yes-vis').click( function (ev) {
         show_yes = ! $(this).hasClass('bold');
         $(this).toggleClass('bold', show_yes);
         redraw_table();
      });

      $('span.toggle-no-vis').click( function (ev) {
         show_no = ! $(this).hasClass('bold');
         $(this).toggleClass('bold', show_no);
         redraw_table();
      });

      $('span.toggle-maybe-vis').click( function (ev) {
         show_maybe = ! $(this).hasClass('bold');
         $(this).toggleClass('bold', show_maybe);
         redraw_table();
      });

      function visible_columns() {
         return table.columns().indexes().toArray().map(idx => table.column(idx).visible() ? 1 : 0)
      }
      function redraw_table() {
         table.rows().every( function() {
             const tr = $(this.node());
             const is_org = tr.data('org');
             const is_sub = is_org ? false : tr.data('chosen') == 'substitute';
             const is_par = is_org ? false : tr.data('chosen') == 'participant';
             const status = tr.data('status')
             show = true

             if( status == 'maybe' && ! show_maybe ) {
                show = false
             }
             if( status == 'no' && ! show_no ) {
                show = false
             }
             if( status == 'yes' && ! show_yes ) {
                show = false
             }
             if( is_org && ! show_org ) {
                show = false
             }
             if( is_par && ! show_par ) {
                show = false
             }
             if( is_sub && ! show_sub ) {
                show = false
             }

             console.log("row", show, "chosen", tr.data('chosen'), "status", status, "show", show );
             tr.toggle(show);
         });
         update_url()
      }
      function update_url() {
        var params = {
          "col": visible_columns().join(''),
          "org": show_org ? 1 : 0,
          "par": show_par ? 1 : 0,
          "sub": show_sub ? 1 : 0,
          "yes": show_yes ? 1 : 0,
          "no" : show_no  ? 1 : 0,
          "maybe": show_maybe ? 1 : 0,
        }
        const url = Object.entries(params).map(([k, v]) => `${k}=${v}`).join('&')
        const url_pdf = url + '&fmt=pdf'
        const url_pdfl = url + '&fmt=pdfl'
        const url_csv = url + '&fmt=csv'
        $('.download-csv').attr('href', url_csv)
        $('.download-pdf').attr('href', url_pdf)
        $('.download-pdfl').attr('href', url_pdfl)
      }

    });
  }
});
