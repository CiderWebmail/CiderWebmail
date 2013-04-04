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
        mail_form.append('layout', 'ajax');
      
        var xhr = new XMLHttpRequest();
        xhr.open('POST', compose_form.action, true);
      
        xhr.upload.addEventListener("progress", function(e) {
            var percent_completed = parseInt(e.loaded / e.total * 100);
            send_mail_progress_bar.style.width = percent_completed + '%';
            send_mail_progress_detail.innerHTML = percent_completed + '%';

            if (percent_completed == 100) {
                $('dialog_button_right').removeEvents('click');
                $('dialog_button_right').addClass('green');
                $('dialog_button_right').removeClass('red');
                $('dialog_button_right').style.width = '120px';
                $('dialog_button_right_text').style.width = '100px';
                $('dialog_button_right_text').innerHTML = 'Upload complete!';
            }

        }, false);

        xhr.onreadystatechange = function(){
            if (xhr.readyState==4 && xhr.status==202) {
                window.location.href = xhr.getResponseHeader('X-Location');
            }
        };

        xhr.addEventListener("error", function(e) {
            //TODO display error
            $('lock_overlay').style.display = 'none';
            $('dialog').style.display = 'none';
        }, false);

        xhr.addEventListener("abort", function(e) {
            $('lock_overlay').style.display = 'none';
            $('dialog').style.display = 'none';
        }, false);


        //setup progress dialog
        $('dialog_progressbar').style.display = 'block';
        $('dialog_title_text').innerHTML = 'Sending mail...';
        window.scrollTo(0,0);
        $('dialog_button_left').style.display = 'none';
        $('dialog_button_right_text').innerHTML = 'Cancel';

        $('dialog_button_right').addEvent('click', function() {
            xhr.abort();
        });

        $('lock_overlay').style.display = 'block';
        $('dialog').style.display = 'block';

        xhr.send(mail_form);
    } else { //othersize just fallback
        compose_form.submit();
    }
}
