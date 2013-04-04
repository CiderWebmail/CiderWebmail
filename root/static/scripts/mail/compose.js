window.addEvent('load', function() {
    new Form.Validator.Inline($('compose_form'), {
        stopOnFailure : true,
        useTitles: true,
        errorPrefix: "",
    });
});

function send_mail(compose_form) {
    //if we support FormData/xhr2
    if (window.FormData !== undefined ) {
        var mail_form = new FormData(compose_form);
      
        var xhr = new XMLHttpRequest();
        xhr.open('POST', compose_form.action, true);
      
        xhr.upload.addEventListener("progress", function(e) {
            var percent_completed = parseInt(e.loaded / e.total * 100);
            document.getElementById('send_mail_progress').innerHTML = "Submission " + percent_completed + "% completed";
        }, false);

        console.log('sending to ' + compose_form.action);
        xhr.send(mail_form);
    } else { //othersize just fallback
        compose_form.submit();
    }
}
