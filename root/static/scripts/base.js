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
