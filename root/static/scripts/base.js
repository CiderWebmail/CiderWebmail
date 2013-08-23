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
        controlpanel.style.width = event.clientX + 'px';
        content.style.left = event.clientX + 'px';
    }
    function drop(event) {
        document.removeEventListener('mousemove', drag);
        document.removeEventListener('mouseup', drop);
        Cookie.write('control_panel_width', event.clientX, {duration: 365});
    }
    document.addEventListener('mousemove', drag, false);
    document.addEventListener('mouseup', drop, false);
    stop_propagation(event);
}

function start_message_view_resize(event) {
    var messages_pane   = document.getElementById('messages_pane');
    var message_view    = document.getElementById('message_view');
    var message_divider = document.getElementById('message_divider');
    function drag(event) {
        var content_top = messages_pane.parentNode.offsetTop;
        messages_pane.style.bottom = messages_pane.parentNode.offsetHeight + content_top
            - event.clientY + 'px';
        message_view.style.top = event.clientY - content_top + 'px';
        message_divider.style.top = event.clientY - content_top + 'px';
    }
    function drop(event) {
        document.removeEventListener('mousemove', drag);
        document.removeEventListener('mouseup', drop);
        Cookie.write(document.getElementById('content').classList.contains('message_display') ? 'message_divider_message_display_top' : 'message_divider_top', event.clientY, {duration: 365});
    }
    document.addEventListener('mousemove', drag, false);
    document.addEventListener('mouseup', drop, false);
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

window.addEventListener('load', function() {
    touch_enabled = check_touch_event_support();

    if (!touch_enabled) {
        document.querySelector('#controlpanel .activeborder')
            .addEventListener('mousedown', start_controlpanel_resize, false);
    }

    var control_panel_width = Cookie.read('control_panel_width')
    if (control_panel_width) {
        document.getElementById('controlpanel').style.width = control_panel_width + 'px';
        document.getElementById('content').style.left = control_panel_width + 'px';
    }

    reset_message_view();

}, false);

function reset_message_view() {
    var message_divider = document.getElementById('message_divider');
    if (message_divider) {
        if (!touch_enabled) {
            message_divider.addEventListener('mousedown', start_message_view_resize, false);
        }

        var message_divider_top = Cookie.read('message_divider_top');
        if (document.getElementById('messages_pane') && message_divider_top) {
            document.getElementById('messages_pane').style.bottom = document.getElementById('messages_pane').parentNode.offsetHeight - message_divider_top + 'px';
            document.getElementById('message_view').style.top     = message_divider_top + 'px';
            message_divider.style.top  = message_divider_top + 'px';
        }
    }
}

// dialog and progress display

//resets the dialog window, hides all elements clears all text
function reset_dialog_box() {
    //hide lock and dialog
    document.getElementById('lock_overlay').style.display = 'none';
    document.getElementById('dialog').style.display = 'none';

    //title and text
    document.getElementById('dialog_title_text').innerHTML = '';
    document.getElementById('dialog_text').innerHTML = '';

    //progressbar
    document.getElementById('dialog_progressbar').style.display = 'none';
    document.getElementById('send_mail_progress_bar').style.width = 0;
    document.getElementById('send_mail_progress_detail').innerHTML = '';

    //buttons
    var dialog_button_left = document.getElementById('dialog_button_left');
    dialog_button_left.style.display = 'none';
    dialog_button_left.removeClass('red');
    dialog_button_left.removeClass('green');
    dialog_button_left.removeClass('grey');
    dialog_button_left.style.width = '50px';
    var dialog_button_left_text = document.getElementById('dialog_button_left_text');
    dialog_button_left_text.style.width = '50px';
    dialog_button_left_text.innerHTML = '';

    var dialog_button_right = document.getElementById('dialog_button_right');
    dialog_button_right.removeEventListener('click', reset_dialog_box, false);
    dialog_button_right.style.display = 'none';
    dialog_button_right.removeClass('red');
    dialog_button_right.removeClass('green');
    dialog_button_right.removeClass('grey');
    dialog_button_right.style.width = '50px';
    var dialog_button_right_text = document.getElementById('dialog_button_right_text');
    dialog_button_right_text.style.width = '50px';
    dialog_button_right_text.innerHTML = '';
}

function show_warning_message(title_text, message_text) {
    reset_dialog_box();

    document.getElementById('dialog_title_text').innerHTML = title_text;
    document.getElementById('dialog_text').innerHTML = message_text;

    var dialog_button_right = document.getElementById('dialog_button_right');
    dialog_button_right.classList.add('grey');
    document.getElementById('dialog_button_right_text').innerHTML = 'Okay';
    dialog_button_right.style.display = 'block';
    dialog_button_right.style.width = '60px';
    
    dialog_button_right.addEventListener('click', reset_dialog_box, false);

    window.scrollTo(0,0);

    document.getElementById('lock_overlay').style.display = 'block';
    document.getElementById('dialog').style.display = 'block';
}

function init_progress_dialog(title_text) {
    reset_dialog_box();

    document.getElementById('dialog_progressbar').style.display = 'block';
    document.getElementById('dialog_title_text').innerHTML = title_text;
    
    document.getElementById('dialog_button_right').addClass('red');
    document.getElementById('dialog_button_right_text').innerHTML = 'Cancel';
    document.getElementById('dialog_button_right').style.display = 'block';
    document.getElementById('dialog_button_right').style.width = '60px';
 
    window.scrollTo(0,0);
    
    document.getElementById('lock_overlay').style.display = 'block';
    document.getElementById('dialog').style.display = 'block';
}

Request.prototype.constructor = Request;
function Request(params) {
    if (params) {
        this.url = params.url;
        this.onSuccess = params.onSuccess;
        this.onError = params.onError;
        this.headers = params.headers ? params.headers : {};
        if (! this.headers.Accept)
            this.headers.Accept = "application/xhtml+xml";
        this.xhr = new XMLHttpRequest();
        var request = this;
        this.xhr.onreadystatechange = function() {
            request.ready_state_changed();
        }
    }
};

Request.prototype.ready_state_changed = function() {
    if (!this.xhr)
        return;
    if (this.xhr.readyState == 4)
        if (this.xhr.status == 200) {
            return this.finish_request();
        }
        else if (this.xhr.status != 0) { // aborting the XMLHttpRequest sets readyState to 4 and status to 0 (shouldn't displayed as error)
            alert('Error: ' + this.xhr.status + " " + this.xhr.statusText + "\n" + this.xhr.responseText);
            if (this.onError)
                this.onError();
        }
}

Request.prototype.finish_request = function() {
    if (this.onSuccess)
        return this.onSuccess(this.xhr.responseText, this.xhr.responseXML);
    else
        return;
}

Request.prototype.param_str = function(params) {
    var paramstr = '';
    for (var key in params)
        paramstr += key + '=' + params[key] + ';';
    return paramstr;
}

Request.prototype.set_headers = function() {
    for (var key in this.headers)
        this.xhr.setRequestHeader(key, this.headers[key]);
}

Request.prototype.send = function(params) {
    this.xhr.open("POST", this.url, true);
    this.set_headers();
    this.xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    this.xhr.send(this.param_str(params));
}

Request.prototype.get = Request.prototype.send;

HTMLRequest.prototype = new Request;
HTMLRequest.prototype.constructor = HTMLRequest;
HTMLRequest.prototype.parent = Request.prototype;
function HTMLRequest(params) {
    this.parent.constructor.call(this, params);
}

HTMLRequest.prototype.finish_request = function() {
    if (this.onSuccess)
        return this.onSuccess(this.xhr.responseXML);
    else
        return;
}

Cookie.prototype.constructor = Cookie;
function Cookie(key) {
    this.key = key;
}

Cookie.prototype.read = function(){
    var value = this.options.document.cookie.match(
        "(?:^|;)\\s*" + this.key.escapeRegExp() + "=([^;]*)"
    );
    return (value) ? decodeURIComponent(value[1]) : null;
}

Cookie.prototype.write = function(value) {
    document.cookie = this.key + "=" + value;
    return this;
}

Cookie.read = function(key) {
    return new Cookie(key);
}

Cookie.write = function(key, value) {
    return new Cookie(key).write(value);
}

function get_coordinates(element) {
    var offset_top = 0;
    var offset_left = 0;
    var offset_height = element.offsetHeight;
    var offset_width = element.offsetWidth;

    while (element) {
        offset_top  += element.offsetTop;
        offset_left += element.offsetLeft;
        element = element.offsetParent;
    }

    return {
        top: offset_top,
        left: offset_left,
        bottom: offset_top + offset_height,
        right: offset_left + offset_width,
    };
}
