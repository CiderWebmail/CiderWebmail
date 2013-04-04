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
        var send_mail_progress        = document.getElementById('send_mail_progress');
        var send_mail_progress_bar    = document.getElementById('send_mail_progress_bar');
        var send_mail_progress_detail = document.getElementById('send_mail_progress_detail');

        send_mail_progress.style.display = 'block';
        compose_form.style.display = 'none';

        var mail_form = new FormData(compose_form);
        mail_form.append('layout', 'ajax');
      
        var xhr = new XMLHttpRequest();
        xhr.open('POST', compose_form.action, true);
      
        xhr.upload.addEventListener("progress", function(e) {
            var percent_completed = parseInt(e.loaded / e.total * 100) - 1; //never report 100%, we replace the document content upon completion 
            send_mail_progress_bar.style.width = percent_completed + '%';
            send_mail_progress_detail.innerHTML = percent_completed + '%';
        }, false);

        xhr.onreadystatechange = function(){
            if (xhr.readyState==4 && xhr.status==202) {
                window.location.href = xhr.getResponseHeader('X-Location');
            }
        };

        xhr.send(mail_form);
    } else { //othersize just fallback
        compose_form.submit();
    }
}
