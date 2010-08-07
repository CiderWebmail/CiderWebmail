function toggleHeader(node, on) {
    node.parentNode.parentNode.parentNode.getElementsByTagName('pre')[0].style.display = on ? '' : 'none';
}

add_event_listener('keyup', function (event) {
        switch (event.keyCode) {
            case 77: // 'm'
                var form = $('content').getElements('form.move_message')[0]
                if (form) {
                    form.style.display = 'block';
                    form.getElementsByTagName('select')[0].focus();
                }
                break;
            case 68: // 'd'
            case 46: // delete key
                if (current_message) {
                    var delete_icon = document.getElementById(current_message.id.replace('message_', 'delete_'));
                    if (! show_next_message())
                        show_previous_message();

                    delete_message(delete_icon);
                }
                break;
        }
    }, false);
