var foto_cat = '';
var anketa_states = [ 'fa-circle-o', 'fa-smile-o', 'fa-meh-o', 'fa-frown-o',  ];
var anketa_td_class = [ 'anketa-nic', 'anketa-yes', 'anketa-maybe', 'anketa-no',  ];
var anketa_txt =    [ ' ', 'y', '?', 'n' ];
ace.vars['base'] = '/ace';



// init tep page
jQuery(document).ready(function($) {
        $('.delete-link').click(function () {
          $('div#delete-file input[name=filename]').val($(this).data('path')).focus();
        });

        $('.secret-menu-toggler').click(function () {
          $('#sidebar').toggleClass('hide');
          $('#main-content-id').toggleClass('main-content');
        });
        $('#menu-toggler').click( function () {
          $('.sidebar').removeClass('hide');
        });

        $('#ckeditor').each( function () { ckeditor_init() } );

        // anketa zvyrazneni, a dekorace
        $('div.anketa').each(function (ii, div) { _init_anketa_div(div) });

        $('.ace-file-input').ace_file_input()
                            .on('change', function () {
                                    $(this).closest('form').submit();
                             });

        if( typeof(TEP_EDITABLE) !== 'undefined'  ) {
          $('div.table-div').each(function (ii, div) { _init_table_edit(div) } );
        }

        var bgimg = $('body').data('background-image');
        if( bgimg ) {
          console.log('bgimg', bgimg);
          $('body').css('background-image', "url(" + bgimg + ")");
        }
        // data tables
	jQuery.extend( jQuery.fn.dataTableExt.oSort, {
	    "locale-pre": function ( a ) {
	        return a.replace(/<[^>]*>/,'');
	    },
	    "locale-asc": function ( a, b ) {
		//console.log("asc:", a, b, a.localeCompare(b));
		return a.localeCompare(b, 'cs') < 0 ? -1 : 1;
	    },
	    "locale-desc": function ( a, b ) {
		//console.log("desc:", a, b, a.localeCompare(b));
		return b.localeCompare(a, 'cs') < 0 ? -1 : 1;
	    },
            "numstr-pre": function ( a ) {
	        a = a.replace(/<[^>]*>/,'');
                return parseInt(a);
            },
            "numstr-asc":  function ( a, b ) { return a - b; },
            "numstr-desc": function ( a, b ) { return b - a; },
	} );

        // orgove klikaci
        $('.org').click( (el_clicked) => {
                on_org_clicked(el_clicked)
        });
        $('.org').on('touched', (el_clicked) => {
                on_org_clicked(el_clicked)
        });


        // trizeni datatabli
        $('.datatable').dataTable({
                "bPaginate": false,
                "bLengthChange": false,
                'resposive': true,
                "bFilter": false,
                "bInfo": false,
                "bAutoWidth": false,
		//"bSort": false,
		"aaSorting": [],
	        "aoColumnDefs": [
					{ "sType": "numstr", "aTargets": [ 0,  ] },
					{ "sType": "locale", "aTargets": [ 1, 2, 3, 4 ] },
			        ],
        });

        init_fotky();

        // formular resitel (novy|editace), schovat adresu skoly, kdyz je vybrana ze seznamu
        $('#school_id').change(function (){
                if('jina' == $(this).val()) {
                  $('#school_div').show(400);
                }
                else {
                  $('#school_div').hide(400);
                }
        });
        var sch = $('#school_id');
        if( sch.length == 1 && sch.val() != 'jina' ) {
          $('#school_div').hide();
        }

        $('#sosna_solver_sex_male, #sosna_solver_sex_female').change(function () {
           $('.sex').toggle( $(this).val() == 'female' )
        });
        if( $("#sosna_solver_sex_male").prop("checked") ) {
           $('.sex').hide()
        }

        $('#sosna_solver_how_i_met_pikomat').change(function (){
                var val = $(this).val()
                $('#how_i_met_pikomat_jina').hide()
                $('#how_i_met_pikomat_kamarad').hide()
                if( val == 'jina'  )  {
                  $('#how_i_met_pikomat_detail_div').show(400)
                  $('#how_i_met_pikomat_jina').show(400)
                }
                else if( val == 'kamarad' )  {
                  $('#how_i_met_pikomat_detail_div').show(400)
                  $('#how_i_met_pikomat_kamarad').show(400)
                }
                else {
                  $('#how_i_met_pikomat_detail_div').hide(400)
                }
        });

        $('#sosna_solver_how_i_met_pikomat').change();

        // které letáky posílat (papíroví; junior jen do 6. ročníku)
        $('select[name="sosna_solver[where_to_send]"], #sosna_solver_grade_num')
          .change(update_paper_level_div);
        update_paper_level_div();

        // výběr školy dle města
        init_school_city_filter();

        // ctrl-enter submit formu in textarea
        $('.ctrl-enter-submit').keydown(function (e) {
                if (e.ctrlKey && e.keyCode == 13) {
                  $(this).closest('form').submit();
                }
        });

        // upload reseni, test jestli jak je soubor velky
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

      init_icons();

      // https://gist.github.com/duncansmart/5267653
      // turn textarea into ace-ecitor
      $('textarea.aceeditor').each(function () {
                var $textarea = $(this);
                _init_textarea_with_ace($textarea);
                // load update version, when user click on browsers 'back'
                reload_on_browser_back();
      });

      // macro youtube
      $('.youtube').each(function () {
                var video = $(this).data('v');
                // autoplay nefunguje, kdyz se to tam appendne po loadu stranky, nevim proc.
                var autoplay = $(this).data('autoplay') || 1;
                //var pct = $(this).data('pct') || 100;
                var w = $(this).parent().width();
                if( w > 1024 ) { w = 1024 }
                var h = w *315/560 ;
                //console.log('youtube', video, "pct", pct);
                $(this).append($('<iframe width="'+w+'" height="'+h+'" '+
                                           'src="https://www.youtube.com/embed/'+escape(video)+'?autoplay=1&amp;controls=0&amp;origin=https://pikomat.mff.cuni.cz/" ' +
                                           'align="left" '+
                                           'type="text/html" '+
                                           'frameborder="0" allowfullscreen></iframe>'
                               ));
      });
      /* pseudo CAPTCHA, tedy robot neumi javascript */
      $('.js-hide').css('display', 'none');
      $('form[data-action]').each(function () { $(this).attr('action', $(this).data('action')); });

      $('#klep-link').each(function() { update_klep_status() });

var colorbox_params = {
              rel: 'colorbox',
       reposition: true,
      scalePhotos: true,
        scrolling: false,
         previous: '<i class="ace-icon fa fa-arrow-left"></i>',
             next: '<i class="ace-icon fa fa-arrow-right"></i>',
            close: '&times;',
          current: '{current} of {total}',
         maxWidth: '100%',
        maxHeight: '100%',
       onComplete: function(){
         $.colorbox.resize();
       }
    }

      /* colorbox */
      $('[data-rel="colorbox"]').colorbox(colorbox_params);
      $('#cboxLoadingGraphic').append("<i class='ace-icon fa fa-spinner orange'></i>");

      $('#adventomat-modal').each(function() { init_adventomat() })
      $('#adventomat-app').each(function() { init_adventomat_app($(this)) })
      $('#device-login-new').each(function() { init_device_login_new($(this)) })
      $('#device-login-keyboard').each(function() { init_device_login_keyboard($(this)) })
      init_friend_widget()
      $('#friend-widget-resend').click(function (ev) {
          ev.preventDefault()
          $.post('/friend/resend', {uuid: friend_get().uuid, authenticity_token: friend_csrf()},
                 function () { alert('Mail poslán znovu. Koukni do schránky.') })
      })
      $('#password_generate').click(function(ev) {
          ev.preventDefault()
          ev.stopPropagation()
          const pass = correct_horse_battery_stable()
          console.log( "gen", pass)
          $('#password_input').val(pass)
      });
      $('#password_copy').click(function(ev) {
          ev.preventDefault()
          ev.stopPropagation()
          const pass = $('#password_input').val()
          console.log( "copy", pass)
          navigator.clipboard.writeText(pass).then(() => {
               console.log("Text copied to clipboard!");
               $('#password_copy').addClass('btn-yellow')
               setTimeout(function () {
                   $('#password_copy').removeClass('btn-yellow')
               }, 2000)
          })
      });
}); //main
     
function init_adventomat() {
      /* adventomat */
      console.log("init_adventomat")
      $('.adventomat-btn').click(function(ev) {
           ev.preventDefault()

           $('#adventomat-date').text($(this).data('date'))
           $('input[name=date]').val($(this).data('date'))
           $('#adventomat-text').text($(this).data('text'))
           $('#adventomat-img').attr('src', $(this).data('img'))
           $('#adventomat-text').data('sol', $(this).data('sol'))

           console.log("adventomat click", this)
           $('#adventomat-modal').modal({keyboard: true, show: true})
      });
      $('.adventomat-cancel').click(function(ev) {
          ev.stopPropagation()
          ev.preventDefault()
          $('#adventomat-modal').modal('hide')
      })
      $('.adventomat-submit').click(function(ev) {
          ev.preventDefault()
          ev.stopPropagation()
          const date =  $('#adventomat-date').text()
          const real_solution= fakedecrypt($('#adventomat-text').data('sol')+'')
          const her_solution= $('input[name="Tvoje řešení"]').val() + ''
          console.log("sol", real_solution, her_solution )
          const is_solved = real_solution.trim() == her_solution.trim()
          const thanks =  is_solved ? 'To je správně.' : 'To je bohužel špatně.'
          if( is_solved ) {
              adventomat_set_solved(date)
              adventomat_set_button_solved(date)
              /* pošli vyřešený den na server, když je adventomat napojený
                 na kvíz (data-quiz na modalu) — viz navrh-kvizy-a-pratele.md */
              var quiz_name = $('#adventomat-modal').data('quiz')
              if (quiz_name) {
                  friend_ensure(function (f) {
                      if (!f) return   // bez přezdívky jen localStorage jako dřív
                      $.post('/quiz/' + quiz_name + '/answer',
                             {uuid: f.uuid, question_no: parseInt(date, 10),
                              answer: her_solution, authenticity_token: friend_csrf()})
                  })
              }
          }
          console.log("thanks", thanks)
          $('input[name=tnx]').val(thanks)
          $('#inform-form').each(function (ev) {
              $(this).submit()
          })
      })
      adventomat_get_solved().forEach( function (day, idx) {
          adventomat_set_button_solved(day)
      })
}

function uniq(arr) {
    return arr.filter( function (value, index, a) {
       return a.indexOf(value) === index;
    });
}

function adventomat_set_solved(id) {
        var values = adventomat_get_solved()
        values.push(id)
        console.log("solved+=", id, localStorage.getItem('adventomat'))
        localStorage.setItem('adventomat', uniq(values).join('|'))
}

function adventomat_get_solved(id) {
        var value = localStorage.getItem('adventomat')
        if( value == null || value == '' ) {
           return []
        }
        return value.split('|')
}

function adventomat_set_button_solved(id) {
        $('button[data-date="'+id+'"]').each( function (idx, el) {
           console.log("tracing", idx, $(this).data('date'))
           if( $(this).data('date') == id ) {
             $(this).addClass('btn-success')
             $(this).removeClass('btn-warning')
             $(this).find('i').removeClass('fa-question').addClass('fa-star')
             console.log("setting solved", this)
           }
        })
}

/* ---- adventomat: kalendář z /quiz/advent-<rok>/kalendar (viz docs/superpowers/specs/2026-11-07-adventomat-design.md) ---- */

function adv_esc(s) {
    return $('<div/>').text(s == null ? '' : String(s)).html()
}

function adv_time(iso) {
    var d = new Date(iso)
    var mm = ('0' + d.getMinutes()).slice(-2)
    return d.getDate() + '. ' + (d.getMonth() + 1) + '. v ' + d.getHours() + ':' + mm
}

var ADV_BTN = { locked: 'btn-default', open: 'btn-warning', solved: 'btn-success', missing: 'btn-default' }
var ADV_ICO = { locked: 'lock', open: 'question', solved: 'star', missing: 'hourglass-half' }

var ADV_SEG_PTS = {
    a: '12,2 48,2 54,8 48,14 12,14 6,8', g: '12,44 48,44 54,50 48,56 12,56 6,50', d: '12,86 48,86 54,92 48,98 12,98 6,92',
    f: '6,11 12,17 12,43 6,49 0,43 0,17', b: '54,11 60,17 60,43 54,49 48,43 48,17',
    e: '6,51 12,57 12,83 6,89 0,83 0,57', c: '54,51 60,57 60,83 54,89 48,83 48,57'
}
var ADV_SEG_ON = ['abcdef', 'bc', 'abged', 'abgcd', 'fgbc', 'afgcd', 'afgedc', 'abc', 'abcdefg', 'abcdfg']

function adv_digit(n) {
    var h = '<svg class="adv-digit" viewBox="-8 0 72 100"><g transform="skewX(-6)">'
    $.each(ADV_SEG_PTS, function (k, pts) {
        h += '<polygon class="' + (ADV_SEG_ON[n].indexOf(k) >= 0 ? 'on' : 'off') + '" points="' + pts + '"/>'
    })
    return h + '</g></svg>'
}

function adv_clock(dd, hh, mi, ss) {
    function grp(v, lbl) {
        var t = ('0' + v).slice(-2)
        return '<div class="adv-grp"><div>' + adv_digit(+t[0]) + adv_digit(+t[1]) + '</div><span>' + lbl + '</span></div>'
    }
    var colon = '<div class="adv-colon on"><i></i><i></i></div>'
    return '<div class="adv-clock" role="timer" aria-label="' + (dd ? dd + ' d ' : '') + hh + ' h ' + mi + ' min ' + ss + ' s">' +
           (dd ? grp(dd, 'dny') + '<div class="adv-gap"></div>' : '') +
           grp(hh, 'hodiny') + colon + grp(mi, 'minuty') + colon + grp(ss, 'sekundy') + '</div>'
}

function adv_reduced_motion() {
    return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)
}

function adv_css() {
    if ($('#adv-anim-css').length) return
    $('<style id="adv-anim-css">' +
      '.adv-key{position:absolute;z-index:1061;pointer-events:none;perspective:160px;transform:translateY(-50%)}' +
      '.adv-key-spin{transition:transform .55s ease-in-out}.adv-key-turn .adv-key-spin{transform:rotateX(180deg)}' +
      '.adv-key i{display:block;font-size:34px;line-height:1;color:#c9970e;text-shadow:0 1px 2px rgba(0,0,0,.45);transform:rotate(135deg)}' +
      '.adv-lock-fly{position:absolute;z-index:1061;pointer-events:none;margin:0;animation:adv-lock-fly .9s ease-in forwards}' +
      '@keyframes adv-lock-fly{25%{transform:translateY(-12px) rotate(-12deg)}100%{transform:translate(-50px,-220px) rotate(-260deg) scale(.4);opacity:0}}' +
      '.adv-spark{position:absolute;z-index:1061;pointer-events:none;font-weight:bold;line-height:1;text-shadow:0 0 4px currentColor}' +
      '.adventomat-day.adv-pop{animation:adv-pop .5s}@keyframes adv-pop{50%{transform:scale(1.2)}}' +
      '.adv-clock{display:inline-flex;align-items:flex-start;gap:6px;max-width:100%;margin:0 0 18px;padding:14px 18px 8px;' +
      'background:#120b0b;border:3px solid #2b2b2b;border-radius:10px;box-shadow:inset 0 0 18px #000,0 2px 6px rgba(0,0,0,.4)}' +
      '.adv-grp{text-align:center}.adv-grp>div{display:flex;gap:4px}' +
      '.adv-grp span{display:block;margin-top:4px;color:#8a5a55;font-size:11px;letter-spacing:.15em;text-transform:uppercase}' +
      '.adv-digit{width:clamp(22px,7vw,52px);height:auto;overflow:visible}' +
      '.adv-digit .on{fill:#ff3b2f;filter:drop-shadow(0 0 3px #ff2a1a)}.adv-digit .off{fill:#2a1513}' +
      '.adv-colon{display:flex;flex-direction:column;justify-content:space-around;height:clamp(32px,10vw,74px);padding:0 2px}' +
      '.adv-colon i{display:block;width:clamp(5px,1.4vw,10px);height:clamp(5px,1.4vw,10px);border-radius:2px;background:#2a1513}' +
      '.adv-colon.on i{background:#ff3b2f;box-shadow:0 0 5px #ff2a1a}.adv-gap{width:clamp(8px,3vw,24px)}' +
      '</style>').appendTo('head')
}

/* Marvin se doploužá k tlačítku, povzdechne si, natáhne ruku, provede act(hand, done) a odploužá se */
function adv_center($b) {
    var $i = $b.find('i').first()
    var o = $i.offset()
    return { left: o.left + $i.outerWidth() / 2, top: o.top + $i.outerHeight() / 2 }
}

function adv_swap($b, st) {
    $b.removeClass('btn-default btn-warning btn-success').addClass(ADV_BTN[st]).addClass('adv-pop')
    $b.find('i').first().removeClass('fa-lock fa-question fa-star fa-hourglass-half').addClass('fa-' + ADV_ICO[st]).css('visibility', '')
    setTimeout(function () { $b.removeClass('adv-pop') }, 600)
}

/* klíč přiletí zprava, zasune se do zámku, otočí se kolem své osy a zámek odletí */
function adv_unlock($b) {
    var dfd = $.Deferred()
    if (!$b.length || !$b.is(':visible')) return dfd.resolve().promise()
    adv_css()
    var c = adv_center($b)
    var $lock = $b.find('i').first()
    var $k = $('<div class="adv-key"><div class="adv-key-spin"><i class="fa fa-key"></i></div></div>')
              .css({ left: $(window).scrollLeft() + $(window).width() + 20, top: c.top }).appendTo('body')
    $k.animate({ left: c.left + 2 }, 900, 'swing', function () {
        $k.addClass('adv-key-turn')
        setTimeout(function () {
            var lo = $lock.offset()
            $lock.clone().addClass('adv-lock-fly').css({ left: lo.left, top: lo.top }).appendTo('body')
                 .on('animationend', function () { $(this).remove() })
            $lock.css('visibility', 'hidden')
            $k.fadeOut(250, function () { $k.remove() })
            setTimeout(function () { adv_swap($b, 'open') }, 350)
            setTimeout(function () { dfd.resolve() }, 900)
        }, 650)
    })
    return dfd.promise()
}

/* otazník se rozprskne na malé otazníky jako ohňostroj a pod ním je zelená s hvězdou */
function adv_burst($b) {
    var dfd = $.Deferred()
    if (!$b.length || !$b.is(':visible')) return dfd.resolve().promise()
    adv_css()
    var c = adv_center($b)
    var colors = ['#f5c518', '#ff5a36', '#36b3ff', '#7ed957', '#ff6ad5', '#ffa62b']
    var parts = []
    for (var i = 0; i < 22; i++) {
        var ang = -Math.PI / 2 + (Math.random() - 0.5) * Math.PI * 1.4, sp = 3 + Math.random() * 5
        parts.push({ el: $('<span class="adv-spark">?</span>').css({ left: c.left, top: c.top, color: colors[i % colors.length],
                                                                       fontSize: 11 + Math.random() * 12 }).appendTo('body'),
                     x: 0, y: 0, vx: Math.cos(ang) * sp, vy: Math.sin(ang) * sp, r: 0, vr: (Math.random() - 0.5) * 24 })
    }
    $b.find('i').first().css('visibility', 'hidden')
    setTimeout(function () { adv_swap($b, 'solved') }, 250)
    var t0 = Date.now(), last = t0, life = 1500
    function frame() {
        var t = Date.now(), k = Math.min(3, (t - last) / 16.7), age = t - t0
        last = t
        parts.forEach(function (p) {
            p.vy += 0.22 * k
            p.x += p.vx * k; p.y += p.vy * k; p.r += p.vr * k
            p.el.css({ transform: 'translate(-50%,-50%) translate(' + p.x + 'px,' + p.y + 'px) rotate(' + p.r + 'deg)',
                       opacity: Math.max(0, 1 - age / life) })
        })
        if (age < life) return setTimeout(frame, 16)
        parts.forEach(function (p) { p.el.remove() })
        dfd.resolve()
    }
    frame()
    return dfd.promise()
}

function init_adventomat_app($app) {
    var year = $app.data('year')
    var base = '/quiz/advent-' + year
    var store = 'adventomat-' + year
    var state = { offset: 0, data: null, timer: null, day: null, prev: null, star: null }

    function cached() {
        try { return JSON.parse(localStorage.getItem(store)) || [] } catch (e) { return [] }
    }
    function cache(list) {
        try { localStorage.setItem(store, JSON.stringify(list)) } catch (e) {}
    }
    function server_now() { return new Date(Date.now() + state.offset) }

    function load() {
        $.ajax({ url: base + '/kalendar', data: { uuid: friend_get().uuid || '' }, cache: false })
         .done(function (data) {
             state.data = data
             state.offset = new Date(data.now) - Date.now()
             if (!data.debug) cache(data.days.filter(function (d) { return d.state === 'solved' }).map(function (d) { return d.no }))
             render()
         })
         .fail(function (x) { $app.html('<p class="red">' + (x.status === 404 ? 'Adventomat ' + year + ' zatím není připravený.' : 'Adventomat se nepodařilo načíst.') + '</p>') })
    }

    function seen_get() {
        try { return JSON.parse(localStorage.getItem(store + '-seen')) } catch (e) { return null }
    }
    function seen_set(list) {
        try { localStorage.setItem(store + '-seen', JSON.stringify(list)) } catch (e) {}
    }

    /* které dny se mají odemknout / ohvězdičkovat animací; do té doby se kreslí v předchozím stavu */
    function plan_animations(d) {
        var plan = { unlock: [], star: [], shown: {} }
        var nos = function (list) { return list.map(function (x) { return x.no }).sort(function (a, b) { return a - b }) }
        var open = d.days.filter(function (x) { return x.state === 'open' })
        if (d.debug) {
            if (state.prev) plan.unlock = nos(open.filter(function (x) { return state.prev[x.no] === 'locked' }))
        } else {
            var seen = seen_get()
            plan.unlock = nos(open.filter(function (x) { return !seen || seen.indexOf(x.no) < 0 })).slice(seen ? -3 : -1)
            seen_set(nos(d.days.filter(function (x) { return x.state !== 'locked' })))
        }
        d.days.forEach(function (x) { if (x.state === 'solved' && x.no === state.star) plan.star = [x.no] })
        state.star = null
        state.prev = {}
        d.days.forEach(function (x) { state.prev[x.no] = x.state })
        if (adv_reduced_motion()) return { unlock: [], star: [], shown: {} }
        plan.unlock.forEach(function (no) { plan.shown[no] = 'locked' })
        plan.star.forEach(function (no) { plan.shown[no] = 'open' })
        return plan
    }

    function render() {
        var d = state.data
        var plan = plan_animations(d)
        var html = ''
        if (d.org) html += debug_bar(d)
        if (d.friend) html += '<p class="grey"><i class="fa fa-user"></i> Hraješ jako <b>' + adv_esc(d.friend.nick) + '</b>' +
                              (window.tep_signed_in ? '' : ' – přihlas se, ať máš vyřešená okénka i na jiném počítači') + '.</p>'
        html += '<div class="adventomat-countdown"></div><div class="adventomat-grid">'
        d.days.forEach(function (day) {
            var st = plan.shown[day.no] || day.state
            var cls = ADV_BTN[st]
            var ico = ADV_ICO[st]
            html += '<button type="button" class="adventomat-day btn btn-app ' + cls + '" data-no="' + day.no + '">' +
                    '<i class="ace-icon fa fa-' + ico + ' bigger-230"></i> ' + adv_esc(day.label) + '</button> '
        })
        html += '</div>'
        if (d.reward) html += '<div class="adventomat-reward well"></div>'
        html += table(d)
        $app.html(html)
        if (d.reward) {
            $.ajax({ url: base + '/odmena', data: { uuid: friend_get().uuid || '' }, cache: false })
             .done(function (j) { $app.find('.adventomat-reward').html(j.html); typeset($app.find('.adventomat-reward')) })
        }
        $app.find('.adventomat-day').click(function (ev) {
            ev.preventDefault()
            open_day(parseInt($(this).data('no'), 10))
        })
        bind_debug()
        tick()
        var btn = function (no) { return $app.find('.adventomat-day[data-no="' + no + '"]') }
        var queue = $.Deferred().resolve().promise()
        plan.unlock.forEach(function (no) { queue = queue.then(function () { return adv_unlock(btn(no)) }) })
        plan.star.forEach(function (no) { queue = queue.then(function () { return adv_burst(btn(no)) }) })
    }

    function table(d) {
        if (!d.table.length) return ''
        var h = '<h4>' + (d.closed ? 'Pořadí k ' + adv_time(d.closes_at) + ' (řešit můžeš dál)' : 'Průběžné pořadí') + '</h4>'
        h += '<table class="table table-condensed table-striped" style="width:auto">'
        d.table.forEach(function (r) {
            h += '<tr><td class="align-right">' + r.count + '</td><td>' + adv_esc(r.nick) +
                 (r.verified ? ' <i class="fa fa-check green" title="ověřený přítel"></i>' : '') + '</td></tr>'
        })
        return h + '</table><p class="grey">V tabulce jsou ti, kdo vyřešili aspoň ' + d.min_table + ' příklady.</p>'
    }

    function tick() {
        clearTimeout(state.timer)
        var d = state.data
        var $c = $app.find('.adventomat-countdown')
        if (!d.next_open_at) { $c.html(''); return }
        var left = Math.floor((new Date(d.next_open_at) - server_now()) / 1000)
        if (left <= 0) { load(); return }
        var dd = Math.floor(left / 86400), hh = Math.floor(left % 86400 / 3600)
        var mi = Math.floor(left % 3600 / 60), ss = left % 60
        adv_css()
        $c.html('<p><i class="fa fa-clock-o"></i> Další okénko se otevře ' + adv_time(d.next_open_at) + '</p>' +
                adv_clock(dd, hh, mi, ss))
        state.timer = setTimeout(tick, 1000)
    }

    function modal() {
        var $m = $('#adventomat-app-modal')
        if ($m.length) return $m
        $m = $('<div id="adventomat-app-modal" class="modal fade" tabindex="-1" role="dialog"><div class="modal-dialog"><div class="modal-content">' +
               '<div class="modal-header"><button type="button" class="close" data-dismiss="modal">&times;</button><h4 class="modal-title"></h4></div>' +
               '<div class="modal-body"><div class="adventomat-text"></div><div class="adventomat-form form-inline" style="margin-top:1em">' +
               '<p class="adventomat-who"></p>' +
               '<input type="text" maxlength="40" class="form-control adventomat-nick" placeholder="tvoje jméno nebo přezdívka"> ' +
               '<input type="text" inputmode="numeric" class="form-control adventomat-answer" placeholder="výsledek – jen číslo"> ' +
               '<button type="button" class="btn btn-primary adventomat-send">Odeslat</button></div>' +
               '<div class="adventomat-msg" style="margin-top:1em"></div></div>' +
               '<div class="modal-footer"><button type="button" class="btn btn-default" data-dismiss="modal">Zavřít</button></div>' +
               '</div></div></div>').appendTo('body')
        $m.find('.adventomat-send').click(function (ev) { ev.preventDefault(); send() })
        $m.find('.adventomat-answer').keypress(function (ev) { if (ev.which === 13) { ev.preventDefault(); send() } })
        return $m
    }

    function open_day(no) {
        var day = state.data.days.filter(function (x) { return x.no === no })[0]
        var $m = modal()
        state.day = day
        $m.find('.modal-title').text(day.no === 25 ? 'Bonus' : 'Příklad na ' + day.no + '. 12.')
        $m.find('.adventomat-msg').html('')
        $m.find('.adventomat-answer').val('')
        var f = friend_get()
        var known = window.tep_signed_in || f.uuid
        $m.find('.adventomat-nick').toggle(!known).val(f.nick || '')
        $m.find('.adventomat-who').html(known ? 'Odpovídáš jako <b>' + adv_esc(f.nick || 'ty') + '</b>.' :
                                        'Napiš své jméno nebo přezdívku – ukáže se v tabulce řešitelů.')
        if (day.state === 'locked' || day.state === 'missing') {
            $m.find('.adventomat-text').html(day.state === 'missing' ? '<p>Tohle okénko ještě připravujeme.</p>' :
                                             '<p><i class="fa fa-lock"></i> Okénko se otevře ' + adv_time(day.opens_at) + '.</p>')
            $m.find('.adventomat-form').hide()
            $m.modal('show')
            return
        }
        $m.find('.adventomat-text').html('<p class="grey">Načítám…</p>')
        $m.find('.adventomat-form').toggle(true)
        if (day.state === 'solved') $m.find('.adventomat-msg').html('<p class="green"><i class="fa fa-star"></i> Tohle už máš vyřešené.</p>')
        $m.modal('show')
        $.ajax({ url: base + '/den/' + day.label, cache: false })
         .done(function (j) { $m.find('.adventomat-text').html(j.html).find('img').css('max-width', '100%'); typeset($m.find('.adventomat-text')) })
         .fail(function (x) { $m.find('.adventomat-text').html('<p class="red">' + adv_esc((x.responseJSON || {}).error || 'Nepodařilo se načíst.') + '</p>') })
    }

    function send() {
        var $m = modal()
        var answer = $m.find('.adventomat-answer').val()
        var no = state.day.no
        var nick = $.trim($m.find('.adventomat-nick:visible').val() || '')
        if ($m.find('.adventomat-nick').is(':visible') && !nick) {
            $m.find('.adventomat-msg').html('<p class="red">Napiš své jméno nebo přezdívku, ať si vyřešené okénko zapamatujeme.</p>')
            $m.find('.adventomat-nick').focus()
            return
        }
        if (nick) friend_set({ nick: nick })
        friend_ensure(function (f) {
            if (!f) {
                $m.find('.adventomat-msg').html('<p class="red">Bez přezdívky si vyřešené okénko nezapamatujeme.</p>')
                return
            }
            $m.find('.adventomat-nick').hide()
            $m.find('.adventomat-who').html('Odpovídáš jako <b>' + adv_esc(f.nick) + '</b>.')
            $.post(base + '/answer', { uuid: f.uuid, question_no: no, answer: answer, authenticity_token: friend_csrf() })
             .done(function (j) {
                 if (j.correct) {
                     $m.find('.adventomat-msg').html('<p class="green bigger-120"><i class="fa fa-star"></i> To je správně!' + (j.debug ? ' (debug, neukládá se)' : '') + '</p>')
                     if (state.day.state !== 'solved') state.star = no
                     $m.one('hidden.bs.modal', load)
                     setTimeout(function () { $m.modal('hide') }, 1200)
                 } else {
                     $m.find('.adventomat-msg').html('<p class="red">To je bohužel špatně.' + (j.solved ? ' Okénko ale máš vyřešené z dřívějška.' : '') + '</p>')
                 }
             })
             .fail(function (x) { $m.find('.adventomat-msg').html('<p class="red">' + adv_esc((x.responseJSON || {}).error || 'Chyba, zkus to znovu.') + '</p>') })
        })
    }

    function typeset($el) {
        if (typeof MathJax == 'object' && MathJax.Hub) MathJax.Hub.Queue(['Typeset', MathJax.Hub, $el[0]])
    }

    function debug_bar(d) {
        var on = !!d.debug
        var val = on ? d.debug.now.slice(0, 16) : (year + '-12-01T03:14')
        return '<div class="alert ' + (on ? 'alert-danger' : 'alert-info') + ' adventomat-debug form-inline">' +
               '<b><i class="fa fa-wrench"></i> ' + (on ? 'DEBUG – čas ' + adv_time(d.debug.now) + ', odpovědi se neukládají' : 'Debug pro orgy') + '</b> ' +
               '<input type="datetime-local" class="form-control input-sm adventomat-debug-now" value="' + val + '"> ' +
               '<button type="button" class="btn btn-sm btn-danger adventomat-debug-set">Nastavit čas</button> ' +
               '<button type="button" class="btn btn-sm btn-warning adventomat-debug-next" title="10 s před otevřením dalšího okénka">Další den <i class="fa fa-forward"></i></button> ' +
               (on ? '<button type="button" class="btn btn-sm btn-default adventomat-debug-off">Skutečný čas</button> ' : '') +
               '<a href="' + base + '/kontrola">kontrola dnů</a></div>'
    }

    function bind_debug() {
        $app.find('.adventomat-debug-set').click(function () {
            $.post(base + '/debug', { now: $app.find('.adventomat-debug-now').val(), authenticity_token: friend_csrf() }).always(load)
        })
        $app.find('.adventomat-debug-next').click(function () {
            $.post(base + '/debug', { next: 1, authenticity_token: friend_csrf() })
             .fail(function (x) { alert((x.responseJSON || {}).error || 'Nepovedlo se.') })
             .always(load)
        })
        $app.find('.adventomat-debug-off').click(function () {
            $.post(base + '/debug', { off: 1, authenticity_token: friend_csrf() }).always(load)
        })
    }

    var quick = cached()
    if (quick.length) $app.find('p.grey').text('Načítám adventomat… (vyřešeno ' + quick.length + ')')
    load()
}

/* ---- přihlášení jiným zařízením (viz docs/superpowers/specs/2026-11-17-prihlaseni-v-mobilu-design.md) ---- */

function dl_css() {
    if ($('#dl-css').length) return
    $('<style id="dl-css">' +
      '.device-login-icons{display:flex;gap:10px;margin:18px 0 6px;max-width:520px}' +
      '.device-login-icon{flex:1 1 0;min-width:0;padding:10px 4px 8px;border:2px solid #d5e3ef;border-radius:10px;background:#f7fbff;text-align:center}' +
      '.device-login-icon .device-login-emoji{display:block;font-size:52px;line-height:1.15}' +
      '.device-login-icon .device-login-name{display:block;margin-top:4px;font-size:16px;font-weight:bold;overflow:hidden;text-overflow:ellipsis}' +
      '.device-login-countdown{font-size:15px;color:#555}' +
      '.device-login-message{margin:10px 0;max-width:520px}.device-login-message:empty{display:none}' +
      '.device-login-ask{font-size:20px;margin:16px 0 12px}' +
      '.device-login-ask .btn{margin:0 6px 6px 0}' +
      '.device-login-slots{display:flex;align-items:center;gap:8px;margin:14px 0}' +
      '.device-login-slot{width:68px;height:68px;border:2px dashed #b9c9d6;border-radius:10px;text-align:center;overflow:hidden;flex:0 0 auto}' +
      '.device-login-slot.filled{border-style:solid;border-color:#6fb3e0;background:#f7fbff}' +
      '.device-login-slot .device-login-emoji{display:block;font-size:30px;line-height:1.3;margin-top:4px}' +
      '.device-login-slot .device-login-name{display:block;font-size:11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding:0 2px}' +
      '.device-login-clear{margin-left:4px}' +
      '.device-login-grid{max-width:520px}' +
      '.device-login-row{display:flex;gap:6px;margin-bottom:6px}' +
      '.device-login-key.btn{flex:1 1 0;min-width:0;padding:6px 2px;white-space:normal;background:#fff !important;border:1px solid #c8d6e2 !important;color:#333 !important;text-shadow:none}' +
      '.device-login-key.btn:hover,.device-login-key.btn:focus{background:#eaf3fb !important;border-color:#6fb3e0 !important}' +
      '.device-login-key .device-login-emoji{display:block;font-size:30px;line-height:1.2}' +
      '.device-login-key .device-login-name{display:block;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}' +
      '.device-login-confirm{max-width:520px;padding:12px 16px;border:2px solid #6fb3e0;border-radius:10px;background:#f7fbff;font-size:15px}' +
      '.device-login-confirm .btn{margin:0 6px 4px 0}' +
      '@media (max-width:420px){.device-login-slot{width:56px;height:60px}.device-login-slot .device-login-emoji{font-size:24px}' +
      '.device-login-slot .device-login-name{font-size:10px;padding:0}' +
      '.device-login-icon{padding:8px 2px 6px}.device-login-icon .device-login-emoji{font-size:40px}.device-login-icon .device-login-name{font-size:13px}.device-login-icons{gap:6px}}' +
      '</style>').appendTo('head')
}

function dl_clock(sec) {
    sec = Math.max(0, Math.ceil(sec))
    return Math.floor(sec / 60) + ':' + ('0' + sec % 60).slice(-2)
}

function dl_error(x, fallback) {
    if (x && x.status === 422) return 'Platnost stránky vypršela, obnov ji prosím.'
    return (x && x.responseJSON && x.responseJSON.error) || fallback
}

function dl_redirect(url) {
    window.location = url
}

function init_device_login_new($el) {
    dl_css()
    var urls = { create: $el.data('create-url'), state: $el.data('state-url'), yes: $el.data('yes-url'), no: $el.data('no-url') }
    var $icons = $el.find('.device-login-icons'), $help = $el.find('.device-login-help')
    var $count = $el.find('.device-login-countdown'), $msg = $el.find('.device-login-message'), $renew = $el.find('.device-login-renew')
    var gen = 0, deadline = 0, phase = null, poll_timer = null, tick_timer = null

    function stop() {
        gen++
        clearTimeout(poll_timer)
        clearTimeout(tick_timer)
        phase = null
        $count.text('')
    }

    function finish(text, cls) {
        stop()
        $icons.empty()
        $help.hide()
        $msg.html('<div class="alert ' + (cls || 'alert-warning') + '">' + adv_esc(text) + '</div>')
        $renew.show().prop('disabled', false)
    }

    function set_deadline(sec) { deadline = Date.now() + sec * 1000 }

    function show_count() {
        $count.text((phase === 'approved' ? 'Potvrď do ' : 'Kód platí ještě ') + dl_clock((deadline - Date.now()) / 1000) + '.')
    }

    function tick() {
        if (deadline <= Date.now()) return finish(phase === 'approved' ? 'Potvrzení vypršelo, začni znovu.' : 'Kód vypršel.')
        show_count()
        tick_timer = setTimeout(tick, 1000)
    }

    function poll(my) {
        poll_timer = setTimeout(function () {
            $.ajax({ url: urls.state, dataType: 'json', cache: false })
             .done(function (d) { if (my === gen) on_state(d, my) })
             .fail(function () { if (my === gen) poll(my) })
        }, 2000)
    }

    function on_state(d, my) {
        if (d.state === 'pending') {
            set_deadline(d.expires_in)
        } else if (d.state === 'approved') {
            set_deadline(d.expires_in)
            if (phase !== 'approved') ask(d.name)
            show_count()
        } else if (d.state === 'done') {
            return finish('Přihlášení už proběhlo.', 'alert-success')
        } else if (d.state === 'cancelled') {
            return finish('Přihlášení bylo zrušeno.')
        } else if (d.state === 'expired') {
            return finish(phase === 'approved' ? 'Potvrzení vypršelo, začni znovu.' : 'Kód vypršel.')
        } else {
            return finish('Kód už neplatí.')
        }
        poll(my)
    }

    function ask(name) {
        phase = 'approved'
        $icons.empty()
        $help.hide()
        $renew.hide()
        $msg.html('<div class="device-login-ask">Přihlásit jako <b>' + adv_esc(name) + '</b>?</div>')
        var $ask = $msg.find('.device-login-ask')
        $('<div/>').appendTo($ask)
          .append('<button type="button" class="btn btn-primary device-login-yes">Ano</button>')
          .append('<button type="button" class="btn btn-default device-login-no">To nejsem já</button>')
        $ask.find('.device-login-yes').click(yes)
        $ask.find('.device-login-no').click(no)
    }

    function yes() {
        $msg.find('button').prop('disabled', true)
        stop()
        var my = gen
        $.ajax({ url: urls.yes, type: 'POST', dataType: 'json', data: { authenticity_token: friend_csrf() } })
         .done(function (d) {
             if (my !== gen) return
             if (d.ok) { $msg.html('<div class="alert alert-success">Přihlašuji…</div>'); dl_redirect(d.url) }
             else finish(d.error || 'Přihlášení se nepovedlo.', 'alert-danger')
         })
         .fail(function (x) { if (my === gen) finish(dl_error(x, 'Přihlášení se nepovedlo, zkus to znovu.'), 'alert-danger') })
    }

    function no() {
        $msg.find('button').prop('disabled', true)
        stop()
        var my = gen
        $.ajax({ url: urls.no, type: 'POST', dataType: 'json', data: { authenticity_token: friend_csrf() } })
         .done(function () { if (my === gen) finish('Zrušeno, nikoho nepřihlašuji.') })
         .fail(function (x) { if (my === gen) finish(dl_error(x, 'Zrušení se nepovedlo, zkus to znovu.'), 'alert-danger') })
    }

    function create() {
        stop()
        var my = gen
        $renew.prop('disabled', true)
        $msg.empty()
        $.ajax({ url: urls.create, type: 'POST', dataType: 'json', data: { authenticity_token: friend_csrf() } })
         .done(function (d) {
             if (my !== gen) return
             $icons.html($.map(d.icons, function (ic) {
                 return '<div class="device-login-icon"><span class="device-login-emoji">' + adv_esc(ic[0]) +
                        '</span><span class="device-login-name">' + adv_esc(ic[1]) + '</span></div>'
             }).join(''))
             $help.show()
             $renew.show().prop('disabled', false)
             phase = 'pending'
             set_deadline(d.expires_in)
             tick()
             poll(my)
         })
         .fail(function (x) { if (my === gen) finish(dl_error(x, 'Kód se nepodařilo vytvořit, zkus to znovu.'), 'alert-danger') })
    }

    $renew.click(create)
    create()
}

function init_device_login_keyboard($el) {
    dl_css()
    var urls = { code: $el.data('code-url'), confirm: $el.data('confirm-url'), cancel: $el.data('cancel-url') }
    var $slots = $el.find('.device-login-slot'), $msg = $el.find('.device-login-message'), $confirm = $el.find('.device-login-confirm')
    var $input = $el.find('.device-login-slots, .device-login-grid')
    var code = [], busy = false, id = null

    function key(i) { return $el.find('.device-login-key[data-i="' + i + '"]') }

    function render() {
        $slots.each(function (n) {
            var $s = $(this)
            if (n < code.length) {
                var $k = key(code[n])
                $s.addClass('filled').html('<span class="device-login-emoji">' + adv_esc($k.find('.device-login-emoji').text()) +
                                           '</span><span class="device-login-name">' + adv_esc($k.find('.device-login-name').text()) + '</span>')
            } else {
                $s.removeClass('filled').empty()
            }
        })
    }

    function say(text, cls) {
        $msg.html(text ? '<div class="alert ' + cls + '">' + adv_esc(text) + '</div>' : '')
    }

    function reset() {
        code = []
        busy = false
        id = null
        render()
        $confirm.addClass('hide')
        $input.show()
        $el.find('.device-login-key, .device-login-clear').prop('disabled', false)
    }

    function submit() {
        busy = true
        $el.find('.device-login-key, .device-login-clear').prop('disabled', true)
        $.ajax({ url: urls.code, type: 'POST', dataType: 'json', data: { code: code, authenticity_token: friend_csrf() } })
         .done(function (d) {
             if (!d.ok) { reset(); return say(d.error || 'Kód neplatí nebo vypršel.', 'alert-danger') }
             id = d.id
             $confirm.find('.device-login-device').html('Přihlásit <b>' + adv_esc(d.device) + '</b>?')
             $confirm.find('.device-login-network').text('Stejná síť jako ty: ' + (d.same_network ? 'ano' : 'ne'))
             $confirm.find('.device-login-age').text('Kód vytvořen před ' + d.age + ' s.')
             $confirm.find('button').prop('disabled', false)
             $input.hide()
             $confirm.removeClass('hide')
         })
         .fail(function (x) {
             reset()
             say(x.status === 401 ? 'Nejsi přihlášený, obnov stránku.' : dl_error(x, 'Chyba, zkus to znovu.'), 'alert-danger')
         })
    }

    function answer(url, ok_text, fail_text, ok_cls) {
        $confirm.find('button').prop('disabled', true)
        $.ajax({ url: url, type: 'POST', dataType: 'json', data: { id: id, authenticity_token: friend_csrf() } })
         .done(function (d) { reset(); say(d.ok ? ok_text : fail_text, d.ok ? ok_cls : 'alert-danger') })
         .fail(function (x) { reset(); say(dl_error(x, fail_text), 'alert-danger') })
    }

    $el.find('.device-login-key').click(function () {
        if (busy || code.length >= 4) return
        say('')
        code.push(String($(this).data('i')))
        render()
        if (code.length === 4) submit()
    })
    $el.find('.device-login-clear').click(function () {
        if (busy) return
        code.pop()
        render()
    })
    $el.find('.device-login-approve').click(function () {
        answer(urls.confirm, 'Hotovo, na druhém zařízení klikni Ano.', 'Potvrzení se nepovedlo, kód mezitím vypršel nebo byl zrušen.', 'alert-success')
    })
    $el.find('.device-login-cancel').click(function () {
        answer(urls.cancel, 'Zrušeno.', 'Zrušení se nepovedlo, kód mezitím vypršel.', 'alert-info')
    })
    reset()
}

function _show(el_selector, want_show) {
        
        if( want_show ) {
                $(el_selector).show(400);
        }
        else {
                $(el_selector).hide(400);
        }
}
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
   if( hash != '' ) {
     window.location.hash = hash;
   }
}


function get_hash()
{
   var hash = window.location.hash.substr(1).split(':');
   return hash; 
}

/*************************************
 * ace-editor support functions
 */

function editor_tool_button_switch($el, editor)
{
  var on = $el.is(':checked');
  var action = $el.data('edit');
  switch(action) {
  case 'vi':
     ace.data.set('vi', on ? 'on' : 'off' );
     if ( on ) {
       ace.require(['ace/keyboard/vim'], function() {
         editor.setKeyboardHandler('ace/keyboard/vim');
         editor.focus();
       });
     } else {
       editor.setKeyboardHandler('');
       editor.focus();
     }
     break;
  case 'wide':
     ace.data.set('wide', on ? 'on' : 'off' );
     if ( on ) {
       $('#editor-container').removeClass('col-xs-6').addClass('col-xs-12');
     }
     else {
       $('#editor-container').removeClass('col-xs-12').addClass('col-xs-6');
     }
     setTimeout(function() { editor.resize(true); }, 0);
     break;
  case 'prev':
     console.log("auto preview", on);
     editor.auto_preview = on;
     editor_try_preview(editor);
     break;
  case 'mobil':
     ace.data.set('mobil', on ? 'on' : 'off' );
     console.log("mobil preview", on);

     $('#textedit').css('display', on ? 'block' : 'none');
     $('.hide-mobil').css('display', on ? 'none' : 'block');
     break;
  }
}

function set_wide_editor(want_wide) {
  console.log("wide");
  $('#widenowide').prop('checked', want_wide).change();
}
     console.log('wide');

function editor_try_preview(editor)
{
  if( editor.auto_preview && ! editor.previewing ) {
    editor.previewing = true;
    editor_preview(editor);
  }
}

function editor_tool_button_click(el, editor)
{
  editor_tool_action($(el).data('edit'), editor);
}

function editor_tool_action(action, editor)
{
  var form = editor.form;
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
  case 'table':   return editor_table(editor);
  case 'save':    return editor_save(editor, false);
  case 'save-stay':return editor_save(editor, true);
  case 'cancel':  return editor_cancel(editor);
  case 'preview': return editor_preview(editor);
  case 'help':       return editor_show_help(editor, action);
  case 'informhelp': return editor_show_help(editor, action);
  case 'icons':    return editor_show_icons(editor);
  default:
          console.log("unknown action", action);
          return editor_wrap(editor, '[[', ']]');
  }
}

function editor_show_help(editor, action)
{
        var form = editor.form;
        editor_show_url(editor, form.find('[data-help-url][data-edit="'+action+'"]').data('help-url'));
}

function editor_show_icons(editor)
{
        var form = editor.form;
        editor_show_url(editor, form.find('[data-icons-url]').data('icons-url'));
}

function init_icons(editor) {
       if( editor ) { 
               $('.icoshow').click(function () {
                 var c = $(this).find('span').text();
                 //console.log("icoshow", c);
                 editor_wrap(editor, '{{ico ' + c + '}}');
               });
       }
       else {

               $('.icoshow').click(function () {
                 $(this).find('span').removeClass('hide');
               });
               $('.icoshow-all').click(function () {
                 console.log("icoshow-all")
                 $('.icoshow').each(function (i, el) {
                   $(el).find('span').removeClass('hide')
                 })
               });
       }
}

function editor_cancel(editor)
{
  //console.log('editor cancel');
  var form = editor.form;
  $(form).find('.editorcancel').each(function (i, el) {
    //console.log('editor cancel');
    window.location =  $(el).attr('href');
  });
}

function editor_reload(editor)
{
  window.location = window.location;
}

function editor_save(editor, stay)
{
  var form = editor.form;
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
       set_wide_editor(false);
       $('#preview-div').html(data['html']||'error');
       init_icons(editor);
     }
   );
}

function editor_preview(editor)
{

   var form = editor.form;
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
       set_wide_editor(false);
       $('#preview-div').html(data['html']||'error');
       if( typeof MathJax == 'object' ) {
         MathJax.Hub.Typeset();
       }
       //FIXME: preview az po vyrenderovani mathjaxu
       editor.previewing = false;
     }
   });
}

function editor_table(editor) {
  var txt = editor.session.getTextRange(editor.getSelectionRange());
  if( txt == '' ) {
     txt = "\n||= title1 =||= title1 =||\n|| A1       || A2       ||\n|| B1       || B2       ||\n";
  }
  else {
    
     var rows = txt.trim().split("\n");
     var table = [];
     var align = [];
     var maxs  = [];
     for(var i=0; i < rows.length; i++ ) {
        table[i] = [];
        align[i] = [];
        var row = rows[i];
        var cells = row.split(/\|\|/);
        if( cells.length > 1 && cells[0].length == 0  ) {
          cells.shift();
        }
        if( cells.length > 1 && cells[cells.length-1].length == 0  ) {
          cells.pop();
        }
        console.log("row", row, cells);
        for(var j=0; j < cells.length;j++) {
          var cell = cells[j];
          console.log("tab", i,j, cell);
          if( cell.charAt(0) == '=' && cell.substr(-1) == '=' ) {
             align[i][j] = 'h';
             cell = cell.substr(1,cell.length - 2);
          }
          cell = cell.trim();
          table[i][j] = cell;
          cell_length = cell.length;
          if( (maxs[j] || 0) < cell_length ) {
              maxs[j] = cell_length;
          }
          console.log("cell=", j, cell_length, cell);
        }
     }
     //txt = editor_table_formater_basic(table, maxs, align);
     txt = editor_table_formater_mediawiki(table, maxs, align);
  }

  editor.insert( txt );
  editor.focus();
}

function editor_table_formater_basic(table, maxs, align) {
  var txt = '';
  for(var i=0; i < table.length; i++ ) {
    var row = table[i];
    txt += "||";
    for(var j=0; j < row.length; j++) {
       var cell = table[i][j];
       var spcs = ' '.repeat( maxs[j] - cell.length );
       var ch = align[i][j] == 'h' ? '=' : ' ';
       txt += ch +  cell + spcs + ch +'||';
    }
    txt += "\n";
  }
  return txt;
}

function editor_table_formater_mediawiki(table, maxs, align) {
  var txt = "{|\n";
  for(var i=0; i < table.length; i++ ) {
    if( i > 0 ) {
      txt += "|-\n";
    }
    for(var j=0; j < table[i].length; j++) {
       txt += "| " + table[i][j] + "\n"
    }
  }
  return txt + "|}\n";
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
  // thi is from app/controller/giwi_controller.rb
  const FAKECRYPT_FROM = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@'
  const FAKECRYPT_TO   = 'pqrstuvwxyzabcdefghijklmnoPQRSTUVWXYZABCDEFGHIJKLMNO314@9870256'

  var ret = '';
  for(var i=0; i < x.length; i++) {
    ret += FAKECRYPT_FROM[FAKECRYPT_TO.indexOf(x[i])] || x[i];
  }
  return ret;

}

function uc_first(s) {
    return s.charAt(0).toUpperCase() + s.slice(1);
}


function _init_textarea_with_ace($textarea) {

        var mode = 'tracwiki';

        var editor = ace.edit('editor-pre', { autoScrollEditorIntoView : true,
                                            });
        $textarea.hide();

        editor.getSession().setMode("ace/mode/" + mode);
        editor.getSession().setUseWrapMode(true);

        editor.setTheme("ace/theme/tomorrow");
        editor.renderer.setShowGutter(true);
        //editor.renderer.setShowInvisibles(true);

        var form = $textarea.closest('form');
        editor.form = form;
        editor.commands.bindKeys({
                        'ctrl-b':       function () { editor_tool_action('bold', editor); },
                        'ctrl-e':       function () { editor_tool_action('table', editor); },
                        'ctrl-i':       function () { editor_tool_action('italic', editor); },
                        'ctrl-escape':  function () { editor_cancel(editor);  },
                        'ctrl-enter':   function () { editor_save(editor, false);  },
                        'shift-enter':  function () { editor_save(editor, true);  },
                        'alt-enter':    function () { editor_preview(editor);  },

                        // toggle vi|nevi mode by pressing vi|nevi switch
                        'ctrl-m':       function () { $('#vinovi').click();},
                        'shift-ctrl-v':       function () { $('#widenowide').click();},
                        'ctrl-alt-enter':       function () { $('#prevmode').click();},

                        // disable default bindings
                        'ctrl-l':null,
                        'ctrl-t':null,
                        //'ctrl-r':null,
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
                console.log("editor.mobil", editor.mobil);
                if( ace.data.get('mobil') == 'off' ) {
                        $textarea.val(editor.getSession().getValue());
                }
                //save_cursor(editor, form);
        });
        //.find('a[data-edit]').click(function () { editor_tool_button_click($textarea, editor); });
        $('a[data-edit]').click(function () {      editor_tool_button_click($(this), editor); });
        $('input[data-edit]').change(function () { editor_tool_button_switch($(this), editor); });
        $('input[data-edit]').each(function (i, el) { editor_tool_button_switch($(el), editor); });
        editor.on('input', function () { editor_try_preview(editor); }); 

        _init_cmdline_editor(editor)
}

function _init_cmdline_editor(editor)
{

        // cmd line
        var cli = ace.edit($('.cmdline')[0]);
        cli.renderer.setShowGutter(true);
        cli.getSession().setValue('ready...');
        cli.getSession().setMode("ace/mode/tracwiki");
        cli.setTheme("ace/theme/tomorrow");
        cli.renderer.setShowGutter(false);

        editor.cmdLine = cli;
        editor.showCommandLine = function(val) {
          this.cmdLine.focus();
          if (typeof val == "string") {
           this.cmdLine.setValue(val, 1);
         }
        };
        editor.commands.addCommand({ name: ':w',   exec: function () { editor_save(editor, true);},               });
        editor.commands.addCommand({ name: ':x',   exec: function () { editor_save(editor, false);},              });
        editor.commands.addCommand({ name: ':wq',  exec: function () { editor_save(editor, false);},              });
        editor.commands.addCommand({ name: ':q',   exec: function () { editor_cancel(editor);},                   });
        editor.commands.addCommand({ name: ':e',   exec: function () { editor_reload(editor);},                   });
        editor.commands.addCommand({ name: ':he',  exec: function () { editor_show_help(editor);},                });
        editor.commands.addCommand({ name: ':ico', exec: function () { editor_show_icons(editor);},               });
        editor.commands.addCommand({ name: ':p',   exec: function () { editor_preview(editor);},                  });
        editor.commands.addCommand({ name: ':pp',  exec: function () { $('#prevmode').click();},                  });

        editor.commands.addCommand({ name: ':i', exec: function () { editor_tool_action('italic', editor);},      });
        editor.commands.addCommand({ name: ':b', exec: function () { editor_tool_action('bold', editor);},        });
        editor.commands.addCommand({ name: ':s', exec: function () { editor_tool_action('strike', editor);},      });
        editor.commands.addCommand({ name: ':$', exec: function () { editor_tool_action('math', editor);},        });
        editor.commands.addCommand({ name: ':t', exec: function () { editor_table(editor);},                      });

        cli.commands.bindKeys({
              //"Shift-Return|Ctrl-Return|Alt-Return": function(cmdLine) { cmdLine.insert("\n"); },
              "Esc|Shift-Esc": function(cmdLine){ editor.focus(); },
              "Return": function(cmdLine) {
                var command = cmdLine.getValue();
                if( command.match(/^:\d+$/)  ) {
                  editor.gotoLine(parseInt(command.substr(1)));
                  editor.focus();
                  return;
                }
                if( command[0] == '/' ) {
                  editor.find(command.substr(1));
                  editor.focus();
                  return;
                }
                var commands = command.split(/\s+/);
                console.log('vi command', command, commands);
                editor.commands.exec(commands[0], editor, commands[1]);
                editor.focus();
              }
        });
}

/********************************************************
 * fotky
 */
function init_fotky()
{
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
        $('#foto-modal').keydown( function (ev) { 
          var code = ev.keyCode || ev.which; 
          var dir = (code == 37) ? 'prev' : // left arrow
                    (code == 39) ? 'next' : //right arrow
                                    null; // not interesting
          if( dir != null) {
            ev.preventDefault();
            $(this).find('button[data-foto-dir=' + dir + ']').click();
          }
        });

        $('button.banner.close').click( function (ev) {
           console.log("banner close click")
           document.cookie = 'hide_banner=1'
        })
        $('.table-edit-arrows input').keydown( function (ev) {
          if( ev.key == 'ArrowDown' || ev.key == 'ArrowUp' ) {
            const td = $(this).closest('td')
            const td_index = td.index()
            const tr = td.closest('tr')
            const tr_next = (ev.key == 'ArrowDown') ? tr.next() : tr.prev()
            const td_next = tr_next.find('td:nth(' + td_index + ')')
            td_next.find('input').first().focus().select()
            console.log('aarrow', tr, tr_next, td_index, td.index(), td_next.index());
            ev.preventDefault();
          }
        });

        $('.foto a').click(function (ev) {
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
                            .css('width', 'auto')
                            .css('image-orientation', 'from-image');
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
}

function _init_anketa_div(div) {
   var pos = parseInt($(div).data('lineno')||0) + 2;
   var ver = $(div).data('version');
   var stat = {};
   var cols_max = 0;
   var cols_max2 = 0;
   var voters = {};
   var $table = $(div).next().find('table');
   //console.log("pos", pos);
   //console.log("csrf", $('meta[name=csrf-token]').attr('content'));

   $table.find('td').first().each(function (i,td) {
     console.log('td in table');
     $(this).addClass('hand');
     $(td).prepend( $('<span class="fa fa-lg fa-plus-square-o">&nbsp;</span>'));

     // click on plus
     $(this).click(function () {

       var $tr = $table.find('.edit-row');
       if( $tr.length > 0  ) {
         $tr.toggle();
         return;
       }

       $tr = $('<tr class="edit-row">');
       var user = ($('.label-user').text() || "anon").replace(/@.*/, '').replace(/ /, '');

       $tr.append($('<td>').append($('<input type="text" name="name"/></td>').val(uc_first(user))));
       console.log("bf add edit row: colsMax", cols_max);
       for (var k = 1; k <= cols_max; k++) {
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
         var row = '|| ' + ($tr.find('input[name=name]').val() || '???' );
         $tr.find('td[data-state]').each(function () { row +=  ' || ' + anketa_txt[parseInt($(this).data('state')||0)] });
         row += '|| ' + ($tr.find('input[name=pozn]').val() || '') + "\n";
         $text.val(row);
         console.log('row:', row);
       });
       var $pozn = $('<input type="text" name="pozn">');
       $tr.append($('<td>').append($pozn));
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
     cols_max2 = Math.max(cols_max2, c);
     if( dostat ) {
             cols_max = Math.max(cols_max, c);
             voters[r] = true;
             stat[c] = stat[c] || {};
             stat[c][txt] = stat[c][txt] || 0;
             stat[c][txt]++;
     }
  });
  if( cols_max == 0 )  {
    cols_max = cols_max2;
  }
  var tab = [];
  //console.log("stat", stat);
  var $tr = $('<tr>').append('<td>&sum;(' + Object.keys(voters).length + ')</td>');
  var max_y = 0;
  var max_ym = 0;
  for (var k in stat ) {
    var ry = stat[k]['y'] || 0;
    var rm = stat[k]['?'] || 0;
    max_y = Math.max(max_y, ry);
    max_ym = Math.max(max_ym, ry+rm);
  }
  console.log('maxym:', max_ym);
  for (var k in stat ) {
    var ret ='';
    var ry = stat[k]['y'] || 0;
    var rn = stat[k]['n'] || 0;
    var rm = stat[k]['?'] || 0;
    var sep = ' ';
    //var sep = '/';
    ret = "<span class='anketa-stat-yes'>" + ry + "</span>" + sep + "<span class='anketa-stat-maybe'>" + rm + "</span>" + sep + "<span class='anketa-stat-no'>" + rn + "</span>";
    //ret = ry + "/" + rm + "/" + rn;
    var $td = $('<td>');
    var title = '';
    if( ry == max_y ) {
      $td.addClass('anketa-max-yes');
      $td.attr('title', "Maximum 'yes'");
    }
    if( ry + rm == max_ym ) {
      $td.addClass('anketa-max-yes-maybe');
      $td.attr('title', ( ry == max_y  ) ? "Maximum 'yes' i 'yes+maybe'" : "Maximum 'yes'");
    }
    $td.html(ret);
    $tr.append($td);
    tab[k] = ret;
  }
  $table.append($tr);
  //console.log('tab', tab);
}

function update_klep_status() {

  $.get('/klepstatus', function (data, textStatus, jqXHR) {
       // data: { "msg_count": 44 }
       var msg_count = data.msg_count;
       //console.log("klep status", msg_count);
       set_klep_status(msg_count);
       setTimeout(function () {update_klep_status()}, 20000)
  });
}

function set_klep_status(msg_count) {
   if( msg_count === undefined || msg_count === null ) {
     //hide count, grey bell
     $('#klep-icon').addClass('light-grey');
     $('#klep-count').addClass('hide');
   } else if( msg_count == 0  ) {
     // hide count, ring not grey
     $('#klep-icon').removeClass('light-grey');
     $('#klep-count').addClass('hide');
   } else { // msg_count > 0
     // show and set count, ring not grey
     $('#klep-icon').removeClass('light-grey');
     $('#klep-count').text(msg_count).removeClass('hide');
   }
   animate_title(msg_count);
}

function animate_title(count) {
  //var want_run = count > 0 ? true : false;

  // disable blinking
  var want_run = false;

  var $title = $('title');
  var timer = $title.data('timer');

  if( want_run ) {
    // want run: star timer
    if( timer  )  {
      // unless it is runnging
      return;
    }
    var time_state = 0;
    var timer = setInterval(function () {
       var want_star = (time_state % 2  == 0)  ?  true : false;
       show_title(count, want_star);
       time_state++;
    }, 1000);
    $title.data('timer', timer);
  }
  else {
    if(  timer )  {
      clearInterval(timer);
      $title.removeData('timer');
    }
  }

  show_title(count, false);
}

//show title once 
function show_title(count, want_star) {

  var $title = $('title');
  var title_text = $title.data('title');

  if( title_text == null ) {
    title_text = $title.text();
    $title.data('title', title_text);
  }
  if( count == undefined || count == 0 ) {
    $title.text(title_text);
    $('#ikona').attr('href', '/images/ikonka32.ico');
  }
  else if( want_star ) {
    $title.text('(*) ' + title_text);
    $('#ikona').attr('href', '/images/ikonka32-green.ico');
  }
  else {
    $title.text('('+count+') ' + title_text);
    $('#ikona').attr('href', '/images/ikonka32-red.ico');
  }
}

// hack based on from https://stackoverflow.com/questions/43043113/how-to-force-reloading-a-page-when-using-browser-back-button
function reload_on_browser_back() {
  window.addEventListener( "pageshow", function ( event ) {
    var historyTraversal = event.persisted || ( typeof window.performance != "undefined" && window.performance.navigation.type === 2 );
    if ( historyTraversal ) {
      window.location.reload();
    }
  });
}


// https://stackoverflow.com/questions/14420300/bootstrap-with-ckeditor-equals-problems/18554395#18554395
function ckeditor_init() {
  const original_text =  $('#textedit').val()
  ClassicEditor.create( document.querySelector( '#ckeditor' ), {               
    toolbar: {
      items: [
              'bold', 'italic', 'strikethrough', 'subscript', 'superscript', '|',
              'blockQuote', 'code', 'codeBlock', 'highlight:blueMarker', 'highlight:greenMarker', '|',
              'bulletedList',  'numberedList',  'outdent', 'indent', '|',
              'insertTable', 'link',
              'heading',
      ]
    },
    removePlugins: [ 'Markdown', 'TextTransformation' ],
    codeBlock: {
                languages: [
                // Do not render the CSS class for the plain text code blocks.
                        { language: 'plaintext', label: 'code', class: '' },
                ],
    }


  }).then( (editor) => {
    console.log("started")
    console.log( "editor",  editor.plugins );
    _update_ckeditor_data( editor, original_text )

    $('.ck-tooltip__text').each(function (i, el) {
      if( el.innerHTML == 'Green marker' ) {
        el.innerHTML = '$ - inline math';
      }
      if( el.innerHTML == 'Blue marker' ) {
        el.innerHTML = '$$ - display math';
      }
    });

    editor.model.document.on('change:data', () => {
      _update_ckeditor_data( editor, original_text )
    })
  })                                                                      

}

function _update_ckeditor_data( editor, original_text )
{
      var html = editor.getData()
      console.log('html:', html)
      //var wiki = html2tracwiki(html, {'old-table': true})
      var wiki = html2tracwiki(html, {})
      console.log("wiki:", wiki)
      var diff_els = Diff.diffChars( original_text, wiki ).map( (d) => {
         if( d.removed ) {
           const txt = d.value
           const rm_char =  /\S/.test(txt) ? '|' : '⋅'
           return $('<span>').text( rm_char ).attr('title', "removed '" + d.value + "'").addClass('red')
         }
         if( d.added ) {
           const txt = d.value.replaceAll("\n", "¶\n") 
           return $('<span>').text( txt ).addClass('diff-green')
         }
         return $('<span>').text(  d.value )
      })
      //$('#ckeditor-output').text( wiki )
      console.log("diff", diff_els)
      $('#ckeditor-output').empty().append(diff_els)
      $('#textedit').val( wiki )
}

function _init_table_edit(div) {
        console.log("Init table");
        const from_line = $(div).data('from-line')
        const to_line = $(div).data('to-line')
        if( ! from_line || ! to_line ) {
                return;
        }
        const pos = `${from_line}-${to_line+1}`
        const href = `${window.location.pathname}?edit=${pos}&ckeditor=1`
        const a =  $('<a/>');
        a.attr('class', 'edittable');
        a.append( $('<i class="fa fa-edit" title="edit table"></i>') )
        a.attr('href',  href )
        $(div).prepend( a );
}

function on_org_clicked(el_clicked) {
        const who = $(el_clicked.target).text()
        console.log("who", who)

        if( $(el_clicked.target).hasClass('org-selected')  ) {
                $('.org').each( (idx, el) => {
                        $(el).removeClass('org-selected')
                        $(el).removeClass('org-unselected')
                });
                return
        }

        $('.org').each( (idx, el) => {
                if( $(el).text() == who ) {
                        $(el).addClass('org-selected')
                        $(el).removeClass('org-unselected')
                }
                else {
                        $(el).addClass('org-unselected')
                        $(el).removeClass('org-selected')
                }
        });
}

/* ---- friend: kvízová identita (viz navrh-kvizy-a-pratele.md) ---- */

function friend_get() {
    try { return JSON.parse(localStorage.getItem('friend')) || {} }
    catch (e) { return {} }
}

function friend_set(f) {
    localStorage.setItem('friend', JSON.stringify({uuid: f.uuid, nick: f.nick}))
}

function friend_csrf() {
    return $('meta[name="csrf-token"]').attr('content')
}

/* Zavolej /friend/status a nastav hlavičkový widget. Přihlášený vyhrává:
   server vrátí kanonického frienda a localStorage se přepíše. */
function init_friend_widget() {
    var f = friend_get()
    if (window.tep_signed_in) {
        $.get('/friend/status', {uuid: f.uuid || ''}, function (json) {
            if (json.merge_candidate &&
                confirm('Na tomto zařízení jsou kvízové odpovědi pod přezdívkou z dřívějška. Připojit k tvému účtu?')) {
                $.post('/friend/claim', {uuid: f.uuid, authenticity_token: friend_csrf()},
                       function (j2) { friend_set(j2) })
            } else {
                friend_set(json)
            }
        })
        return
    }
    if (!f.uuid && !f.nick) return   // stav 1: nic — zůstává jen Přihlášení
    $.get('/friend/status', {uuid: f.uuid || ''}, function (json) {
        if (json.status === 'unknown') return
        friend_set(json)
        $('#friend-widget-nick').text(json.nick)
        $('#friend-widget').removeClass('hide')
        $('#friend-login-link').addClass('hide')
        if (json.status === 'unverified') {          // stav 3: trojúhelníček + resend
            $('#friend-widget-warn').removeClass('hide')
            $('.friend-anonymous').addClass('hide')
            $('.friend-unverified').removeClass('hide')
        } else {                                     // stav 2: vykřičník
            $('#friend-widget-bang').removeClass('hide')
        }
    })
}

/* Zajisti frienda (lazy) a předej ho callbacku. Ptá se na nick, když chybí. */
function friend_ensure(cb) {
    var f = friend_get()
    if (f.uuid) return cb(f)
    if (window.tep_signed_in) {
        $.get('/friend/status', function (json) { friend_set(json); cb(json) })
        return
    }
    var nick = f.nick || prompt('Zadej přezdívku do výsledkovky (nepovinné):')
    if (!nick) return cb(null)
    $.post('/friend/hello', {nick: nick, authenticity_token: friend_csrf()}, function (json) {
        friend_set(json)
        cb(json)
    })
}

/* registrace řešitele: které letáky posílat — blok jen při papírovém
   zasílání (home/school), junior checkbox jen do 6. ročníku */
function update_paper_level_div() {
    if ($('#paper_level_div').length === 0) return
    var wts = $('select[name="sosna_solver[where_to_send]"]').val()
    _show('#paper_level_div', wts === 'home' || wts === 'school')
    var grade = parseInt($('#sosna_solver_grade_num').val(), 10)
    var jr = $('#paper_jr_label')
    if (grade > 6) {
        jr.hide()
        jr.find('input[type=checkbox]').prop('checked', false)
    } else {
        jr.show()
    }
}

/* výběr školy dle města (přihláška řešitele): #school_city filtruje
   #school_id přes data-city; „Jiné město" => rovnou „Jiná škola";
   u „Jiná škola" s vybraným městem se město předvyplní do formuláře
   nové školy. Server město nečte — čistě klientský komfort. */
function init_school_city_filter() {
    var city = $('#school_city')
    var school = $('#school_id')
    if (city.length === 0 || school.length === 0) return

    // plný seznam opcí si zapamatuj (filtruje se rebuild-em)
    var all = school.find('option').map(function () {
        return { value: $(this).val(), text: $(this).text(),
                 city: $(this).data('city') || null }
    }).get()

    function rebuild(selectedCity, keepValue) {
        school.empty()
        var seenJina = false
        all.forEach(function (o) {
            if (o.value === 'jina' && seenJina) return   // druhá „Jiná škola" na konci
            if (o.city === null || selectedCity === 'none' || o.city === selectedCity) {
                if (o.value === 'jina') seenJina = true
                school.append($('<option>').val(o.value).text(o.text)
                                           .attr('data-city', o.city))
            }
        })
        school.val(keepValue !== undefined ? keepValue : 'none')
        if (school.val() === null) school.val('none')
    }

    city.change(function () {
        var c = city.val()
        if (c === 'jine') {
            rebuild('__nic__', 'jina')       // jen „Vyber/Jiná škola" -> rovnou jiná
        } else {
            var cur = school.val()
            var curCity = school.find('option:selected').data('city')
            rebuild(c, (c !== 'none' && curCity && curCity !== c) ? 'none' : cur)
            // jediná škola ve městě -> vyber ji rovnou; u dvou a více
            // zůstává „Vyber školu" (pseudo-školy bez města se nepočítají)
            if (c !== 'none' && school.val() === 'none') {
                var reals = school.find('option').filter(function () {
                    return $(this).data('city') === c
                })
                if (reals.length === 1) school.val(reals.val())
            }
        }
        school.change()                      // ať se ukáže/schová school_div
        prefill_city()
    })

    school.change(prefill_city)

    function prefill_city() {
        if (school.val() !== 'jina') return
        var c = city.val()
        var f = $('#sosna_school_city')
        if (c && c !== 'none' && c !== 'jine' &&
            (f.val() === '' || f.data('autofilled'))) {
            f.val(c).data('autofilled', true)
        }
    }

    // obnova stavu (reload / redisplay po chybě): odvoď město z vybrané školy
    var initCity = school.find('option:selected').data('city')
    if (initCity) {
        city.val(initCity)
        rebuild(initCity, school.find('option:selected').val())
    } else if (school.val() === 'jina' && $('#sosna_school_city').val()) {
        var known = city.find('option[value="' + $('#sosna_school_city').val().replace(/\s+\d+.*$/, '') + '"]')
        city.val(known.length ? known.val() : 'jine')
        if (known.length) rebuild(known.val(), 'jina')
    }
}
