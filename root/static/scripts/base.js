function open_in_new_window(link) {
    window.open(link);
    return false;
}

function add_attachment(adder) {
    var attachment = adder.parentNode;
    attachment.parentNode.insertBefore(attachment.cloneNode(true), attachment.nextSibling);
    attachment.removeChild(adder);
    return false;
}

function stop_propagation(event) {
    if (event.stopPropagation) event.stopPropagation();
    event.cancelBubble = true;

    if (event.preventDefault) event.preventDefault();
    else event.returnValue = false;
}

function start_controlpanel_resize(event) {
    var controlpanel = document.getElementById('controlpanel');
    var content = document.getElementById('content');
    function drag(event) {
        controlpanel.style.width = event.client.x + 'px';
        content.style.left = event.client.x + 'px';
    }
    function drop(event) {
        document.removeEvent('mousemove', drag);
        document.removeEvent('mouseup', drop);
        Cookie.write('control_panel_width', event.client.x, {duration: 365});
    }
    document.addEvents({mousemove: drag, mouseup: drop});
    stop_propagation(event);
}

function start_message_view_resize(event) {
    var messages_pane   = document.getElementById('messages_pane');
    var message_view    = document.getElementById('message_view');
    var message_divider = document.getElementById('message_divider');
    function drag(event) {
        messages_pane.style.bottom = messages_pane.parentNode.offsetHeight - event.client.y + 'px';
        message_view.style.top = event.client.y + 'px';
        message_divider.style.top = event.client.y + 'px';
    }
    function drop(event) {
        document.removeEvent('mousemove', drag);
        document.removeEvent('mouseup', drop);
        Cookie.write($('content').hasClass('message_display') ? 'message_divider_message_display_top' : 'message_divider_top', event.client.y, {duration: 365});
    }
    document.addEvents({mousemove: drag, mouseup: drop});
    stop_propagation(event);
}

var touch_enabled = false;

function check_touch_event_support(){
    try {
        document.createEvent("TouchEvent");
        return true;
    } catch(e) {
        return false;
    }
}

window.addEvent('load', function() {
    touch_enabled = check_touch_event_support();

    if (!touch_enabled) { $$('#controlpanel .activeborder').addEvent('mousedown', start_controlpanel_resize); }

    var control_panel_width = Cookie.read('control_panel_width')
    if (control_panel_width) {
        $('controlpanel').style.width = control_panel_width + 'px';
        $('content').style.left = control_panel_width + 'px';
    }

    reset_message_view();

});

function reset_message_view() {
    var message_divider = $('message_divider');
    if (message_divider) {
        if (!touch_enabled) { message_divider.addEvent('mousedown', start_message_view_resize); }

        var message_divider_top = Cookie.read('message_divider_top');
        if ($('messages_pane') && message_divider_top) {
            $('messages_pane').style.bottom = $('messages_pane').parentNode.offsetHeight - message_divider_top + 'px';
            $('message_view').style.top     = message_divider_top + 'px';
            message_divider.style.top  = message_divider_top + 'px';
        }
    }
}

// dialog and progress display

//resets the dialog window, hides all elements clears all text
function reset_dialog_box() {
    //hide lock and dialog
    $('lock_overlay').style.display = 'none';
    $('dialog').style.display = 'none';

    //title and text
    $('dialog_title_text').innerHTML = '';
    $('dialog_text').innerHTML = '';

    //progressbar
    $('dialog_progressbar').style.display = 'none';
    $('send_mail_progress_bar').style.width = 0;
    $('send_mail_progress_detail').innerHTML = '';

    //buttons
    $('dialog_button_left').removeEvents('click');
    $('dialog_button_left').style.display = 'none';
    $('dialog_button_left').removeClass('red');
    $('dialog_button_left').removeClass('green');
    $('dialog_button_left').removeClass('grey');
    $('dialog_button_left').style.width = '50px';
    $('dialog_button_left_text').style.width = '50px';
    $('dialog_button_left_text').innerHTML = '';

    $('dialog_button_right').removeEvents('click');
    $('dialog_button_right').style.display = 'none';
    $('dialog_button_right').removeClass('red');
    $('dialog_button_right').removeClass('green');
    $('dialog_button_right').removeClass('grey');
    $('dialog_button_right').style.width = '50px';
    $('dialog_button_right_text').style.width = '50px';
    $('dialog_button_right_text').innerHTML = '';
}

function show_warning_message(title_text, message_text) {
    reset_dialog_box();

    $('dialog_title_text').innerHTML = title_text;
    $('dialog_text').innerHTML = message_text;

    $('dialog_button_right').addClass('grey');
    $('dialog_button_right_text').innerHTML = 'Okay';
    $('dialog_button_right').style.display = 'block';
    $('dialog_button_right').style.width = '60px';
    
    $('dialog_button_right').addEvent('click', function() {
        reset_dialog_box();
    });

    window.scrollTo(0,0);

    $('lock_overlay').style.display = 'block';
    $('dialog').style.display = 'block';
}

function init_progress_dialog(title_text) {
    reset_dialog_box();

    $('dialog_progressbar').style.display = 'block';
    $('dialog_title_text').innerHTML = title_text;
    
    $('dialog_button_right').addClass('red');
    $('dialog_button_right_text').innerHTML = 'Cancel';
    $('dialog_button_right').style.display = 'block';
    $('dialog_button_right').style.width = '60px';
 
    window.scrollTo(0,0);
    
    $('lock_overlay').style.display = 'block';
    $('dialog').style.display = 'block';
}
