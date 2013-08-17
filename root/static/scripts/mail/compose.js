window.addEventListener('load', function() {
    new Form.Validator.Inline($('compose_form'), {
        stopOnFailure : true,
        useTitles: true,
        errorPrefix: "",
    });
}, false);

function send_mail(compose_form) {
    //if we support FormData/xhr2
    if (window.FormData !== undefined ) {
        var mail_form = new FormData(compose_form);
        mail_form.append('layout', 'ajax');
      
        var xhr = new XMLHttpRequest();
        var abort_function = function() {
            xhr.abort();
        };
        xhr.open('POST', compose_form.action, true);

        var dialog_button_right = document.getElementById('dialog_button_right');
        var dialog_button_right_text = document.getElementById('dialog_button_right_text');
      
        xhr.upload.addEventListener("progress", function(e) {
            var percent_completed = parseInt(e.loaded / e.total * 100);
            send_mail_progress_bar.style.width = percent_completed + '%';
            send_mail_progress_detail.innerHTML = percent_completed + '%';

            if (percent_completed == 100) {
                dialog_button_right.removeEventListener('click', abort_function, false);
                dialog_button_right.classList.add('green');
                dialog_button_right.classList.remove('red');
                dialog_button_right.style.width = '120px';
                dialog_button_right_text.style.width = '100px';
                dialog_button_right_text.innerHTML = 'Upload complete!';

                //everything after this is handled by the xhr.onreadystatechange functions
            }

        }, false);

        xhr.onreadystatechange = function(){
            if (xhr.readyState==4 && xhr.status==202) {
                window.setTimeout(function() {
                    window.location.href = xhr.getResponseHeader('X-Location');
                }, 1500);
            }

            if (xhr.readyState==4 && xhr.status==400) {
                var error = JSON.decode(xhr.responseText);

                show_warning_message('', error.message);
            }
            
            if (xhr.readyState==4 && xhr.status==500) {
                //TODO improve error handling, redirect user
                show_warning_message('', "Internal Server Error");
            }
        };

        xhr.addEventListener("error", function(e) {
            //TODO improve error handling, redirect user
            show_warning_message('', "Internal Server Error");
        }, false);

        xhr.addEventListener("abort", function(e) {
            reset_dialog_box();
        }, false);

        init_progress_dialog('Sending Mail...');

        dialog_button_right.addEventListener('click', abort_function, false);

        xhr.send(mail_form);
    } else { //othersize just fallback
        compose_form.submit();
    }
}
