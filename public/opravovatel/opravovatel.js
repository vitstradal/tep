var op_score = 1
var oprava_info = {}

function  opravovatelLoaded() {
  var saveButton = document.getElementById('saveButton')
  saveButton.addEventListener("click", function () {
    const pdfApp = window.PDFViewerApplication
    set_save_button_disabled(false)
    set_document_state('Saving')
    save_settings()
    fetch("/piki/index.csrf")
      .then(response => response.json() )
      .then(response_json => {
        const csrf_token = response_json["csrf"]
        console.log("csrf resp", csrf_token )
        pdfApp.pdfDocument.saveDocument().then(data => {
          const blob = new Blob([data], { type: "application/pdf" });
          const formData = new FormData();
          formData.append("file_rev", blob, 'rev.pdf');
          fetch(url_for('up_rev'), {
            method: "POST",
            headers: {
              'X-CSRF-Token': csrf_token, 
            },
            body: formData,
            credentials: "same-origin"
          }).then(response => {
            if(response.ok ) {
              console.log("PDF saved!")
              pdfApp.pdfDocument.annotationStorage.resetModified()
              set_save_button_disabled(true)
              set_document_state('Saved')
            }
            else {
              console.log("Failed to save PDF." + response.code);
              set_save_button_disabled(false)
              set_document_state('Error')
            }
          });
        }).catch(err => {
          console.error("Save error:", err);
          alert("Error saving PDF.");
        });
        console.log("url", window.PDFViewerApplication.url)
      });
  });
  window.PDFViewerApplication.eventBus.on("metadataloaded", () => {
    document.getElementById('title').innerHTML= "TEP opravovatel"
  })
  window.PDFViewerApplication.eventBus.on("documentinit", () => {
     console.log("EVENT: document init")
     set_save_button_disabled(true)
     set_document_state('Loaded')
     const onSetModified_orig = window.PDFViewerApplication.pdfDocument.annotationStorage.onSetModified
     const onResetModified_orig = window.PDFViewerApplication.pdfDocument.annotationStorage.onSetResModified
     window.PDFViewerApplication.pdfDocument.annotationStorage.onSetModified = () => {
       console.log("onSetModified")
       set_save_button_disabled(false)
       set_document_state('Modified')
       onSetModified_orig()
     }
//     window.PDFViewerApplication.pdfDocument.annotationStorage.onResetModified = () => {
//       console.log("onResetModified")
//       set_save_button_disabled(true)
//       onSetModified_orig()
//     }
  })
  //set_save_button_disabled( ! window.PDFViewerApplication.pdfDocument.annotationStorage._annotationStorageModified )
  init_op_info()
}

function save_settings() {
  const inkColor = window.PDFViewerApplication.annotationEditorParams.editorInkColor.value
  const fontSize = window.PDFViewerApplication.annotationEditorParams.editorFreeTextFontSize.value
  console.log("inkColor", inkColor, "fontSize", fontSize)
}
  
function set_document_state(document_state) {
  console.log('ducment state', document_state)
  document.getElementById('documentState').innerHTML = document_state
}

function set_save_button_disabled(want_disabled) {
  console.log("disableing save button", want_disabled ? "DISABLE" : "ENABLE" )
  var save_button = document.getElementById('saveButton')
  save_button.disabled = want_disabled
  document.getElementById('saveButton').classList.toggle( 'saveButtonDisabled',  want_disabled)
  document.getElementById('saveButton').classList.toggle( 'saveButtonEnabled',  !want_disabled)
}

function init_op_info() {
  fetch( url_for('info') )
    .then( response => response.json() )
    .then( response_json => {
      update_info(response_json)
      oprava_info = response_json
    })
}

function update_info(info) {
  set_score(info.score || '-')
  const problem = info.problem
  const title  = `| ${info.index}/${info.total_count} | r${problem.annual} s${problem.round} ul${problem.problem_no} | ${info.solver.full_name}`
  document.getElementById('fullNameText').innerHTML =  title

  document.getElementById('nextButton').disabled = info.next_solution_id == null
  document.getElementById('nextButton').title = info.next_solution_id
  document.getElementById('prevButton').disabled = info.prev_solution_id == null
  document.getElementById('prevButton').title = info.prev_solution_id
  document.getElementById('tepLink').href = `/sosna/solutions/${problem.annual}/${problem.level}/${problem.round}`
  document.getElementById('resetButton').innerHTML = is_reset() ? 'unRESET' : 'RESET'

}

function is_reset() {
  return window.PDFViewerApplication.url.endsWith('/down');
}

function go_to_reset() {
  if( is_reset() ) {
    // unreset
    window.location.href = `/opravovatel?file=${url_for('down_rev')}`
  } else {
    window.location.href = `/opravovatel?file=${url_for('down')}`
  }
}

function go_to_prev() {
        window.location.href = `/opravovatel?file=/sosna/solution/${oprava_info.prev_solution_id}/down_rev`
}
function go_to_next() {
        window.location.href = `/opravovatel?file=/sosna/solution/${oprava_info.next_solution_id}/down_rev`
}

function set_score_and_update(n) {
  set_score(n);
  update_score(score)
}

function set_score(n) {
  score = n;
  //console.log("score", score);
  document.getElementById('scoreButton0').classList.toggle('yellow', score == '0' )
  document.getElementById('scoreButton1').classList.toggle('yellow', score == '1' )
  document.getElementById('scoreButton2').classList.toggle('yellow', score == '2' )
  document.getElementById('scoreButton3').classList.toggle('yellow', score == '3' )
  document.getElementById('scoreButton4').classList.toggle('yellow', score == '4' )
  document.getElementById('scoreButton5').classList.toggle('yellow', score == '5' )
  document.getElementById('scoreButtonReset').classList.toggle('yellow', score == '-' )
}

function url_for(action) {
  return window.PDFViewerApplication.url.replace(/\/down(_rev)?$/, `/${action}`)
}

function update_score(score) {
  const solution_id = oprava_info.id
  const update_score_url = '/sosna/solutions/update_scores'
  fetch("/piki/index.csrf")
    .then(response => response.json() )
    .then(response_json => {
      const csrf_token = response_json["csrf"]
      const formData = new FormData();
      formData.append(`score[${solution_id}]`, score )
      fetch(update_score_url, {
        method: "POST",
        headers: {
          'X-CSRF-Token': csrf_token, 
        },
        body: formData,
        credentials: "same-origin"
      }).then(response => {
        console.log(response.ok ? "Score" : "Failed to save Score." + response.code);
      });
    }).catch(err => {
        console.error("Save error:", err);
        alert("Error saving Scrore.");
    });
}

document.addEventListener('appconfigured', () => {
  opravovatelLoaded();
})
