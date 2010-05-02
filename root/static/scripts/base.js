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

function add_event_listener(eventname, handler, bubble) {
    if (document.addEventListener) document.addEventListener(eventname, handler, bubble);
    else document.attachEvent('on' + eventname, handler);
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
    }
    document.addEvents({mousemove: drag, mouseup: drop});
    stop_propagation(event);
}

window.addEvent('load', function() {
    $$('#controlpanel .activeborder').addEvent('mousedown', start_controlpanel_resize);
    $('message_divider').addEvent('mousedown', start_message_view_resize);
});
