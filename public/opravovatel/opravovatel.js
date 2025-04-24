var op_score = 1
var op_info = {}

function  opravovatelLoaded() {

  var csrf_token;
  fetch("/piki/index.csrf")
  .then(response => response.json() )
  .then(data => { csrf_token = data["csrf"] })

  var saveButton = document.getElementById('downloadButton2')
  saveButton.addEventListener("click", function () {
    const pdfApp = window.PDFViewerApplication
    pdfApp.pdfDocument.saveDocument().then(data => {
      const blob = new Blob([data], { type: "application/pdf" });
      const formData = new FormData();
      formData.append("file_rev", blob, 'rev.pdf');
      fetch("/sosna/solution/127707/up", {
        method: "POST",
        headers: {
          'X-CSRF-Token': csrf_token, 
        },
        body: formData,
        credentials: "same-origin"
      }).then(response => {
        alert(response.ok ? "PDF saved!" : "Failed to save PDF." + response);
      });
    }).catch(err => {
      console.error("Save error:", err);
      alert("Error saving PDF.");
    });
    console.log("url", window.PDFViewerApplication.url)
  });
  init_op_info()
}

function init_op_info() {
  const url =  window.PDFViewerApplication.url
  const url_info = url.replace(/\/down(_rev)?$/, "/info")
  fetch( url_info )
    .then( response => response.json() )
    .then( response_json => {
      update_info(response_json)
    })
}

function update_info(info) {
  console.log("info response:", info )
  set_score(info.score || '-')
  const problem = info.problem
  document.getElementById('fullNameText').innerHTML =  `r${problem.annual} s${problem.round} ul${problem.problem_no} ${info.solver.full_name}`
}

function set_score(n) {
  score = n;
  console.log("score", score);
  document.getElementById('scoreButton0').classList.toggle('yellow', score == '0' )
  document.getElementById('scoreButton1').classList.toggle('yellow', score == '1' )
  document.getElementById('scoreButton2').classList.toggle('yellow', score == '2' )
  document.getElementById('scoreButton3').classList.toggle('yellow', score == '3' )
  document.getElementById('scoreButton4').classList.toggle('yellow', score == '4' )
  document.getElementById('scoreButton5').classList.toggle('yellow', score == '5' )
  document.getElementById('scoreButtonReset').classList.toggle('yellow', score == '-' )
}

if (document.readyState === "interactive" || document.readyState === "complete") {
  opravovatelLoaded();
} else {
  document.addEventListener("DOMContentLoaded", opravovatelLoaded, true);
}
