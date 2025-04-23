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
  });
}

if (document.readyState === "interactive" || document.readyState === "complete") {
  opravovatelLoaded();
} else {
  document.addEventListener("DOMContentLoaded", opravovatelLoaded, true);
}
