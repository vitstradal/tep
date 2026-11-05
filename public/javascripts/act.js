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
      const controls = $('#act_display_controls')
      const view = controls.data('view')
      const num_attrs = controls.data('attrs')
      const table = new DataTable('#act_display_participants', {
          paging: false,
          ordering: false,
          searching: false,
          info: false,
          scrollY: false,
          scrollX: true
      });

      function set_on(el, on) {
         $(el).toggleClass('btn-primary', on).toggleClass('btn-white', !on)
      }
      function is_on(el) {
         return $(el).hasClass('btn-primary')
      }
      function show_column(idx, show) {
         set_on($('button.toggle-vis[data-column="' + idx + '"]'), show)
         table.column(idx).visible(show, false)
      }

      $('button.toggle-vis').click( function (ev) {
          const idx = $(this).data('column')
          show_column(idx, !is_on(this))
          table.columns.adjust().draw(false)
          update_url()
      });
      $('button.clear-vis').click( function (ev) {
         const name_cols = [1, 2]
         for (let idx = 0; idx < num_attrs; idx++) show_column(idx, name_cols.includes(idx))
         table.columns.adjust().draw(false)
         update_url()
      });
      $('button.toggle-group').click( function (ev) {
         const group = $(this).data('group')
         view[group] = is_on(this) ? 0 : 1
         set_on(this, view[group] == 1)
         redraw_table()
      });
      $('button.set-sort').click( function (ev) {
         view.sort = $(this).data('sort')
         window.location.search = query()
      });
      $('button.set-empty').click( function (ev) {
         view.empty = $(this).data('empty')
         window.location.search = query()
      });

      function visible_columns() {
         const cols = []
         for (let idx = 0; idx < num_attrs; idx++) cols.push(table.column(idx).visible() ? 1 : 0)
         return cols
      }
      function redraw_table() {
         table.rows().every( function() {
             const tr = $(this.node());
             const header = tr.data('group')
             if (header) {
                tr.toggle(view[header] == 1)
                return
             }
             const is_org = tr.data('org') == 1;
             const group = is_org ? 'org' : (tr.data('chosen') == 'substitute' ? 'sub' : 'par')
             tr.toggle(view[group] == 1 && view[tr.data('status')] == 1);
         });
         update_url()
      }
      function query() {
        const params = {
          "col": visible_columns().join(''),
          "org": view.org, "par": view.par, "sub": view.sub,
          "yes": view.yes, "no": view.no, "maybe": view.maybe,
          "sort": view.sort, "empty": view.empty,
        }
        return '?' + Object.entries(params).map(([k, v]) => `${k}=${v}`).join('&')
      }
      function update_url() {
        const url = query()
        history.replaceState(null, '', url)
        $('.download-csv').attr('href', url + '&fmt=csv')
        $('.download-pdf').attr('href', url + '&fmt=pdf')
        $('.download-pdfl').attr('href', url + '&fmt=pdfl')
      }

      view.col.split('').forEach((c, idx) => { if (idx < num_attrs) table.column(idx).visible(c == '1', false) })
      table.columns.adjust().draw(false)
      redraw_table()
    });
  }
});
