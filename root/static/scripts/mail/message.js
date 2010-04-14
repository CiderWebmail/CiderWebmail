function toggleHeader(node, on) {
    node.parentNode.parentNode.parentNode.getElementsByTagName('pre')[0].style.display = on ? '' : 'none';
}

add_event_listener('keyup', function (event) {
        if (event.keyCode == 77) {
            var form = $('content').getElements('form.move_message')[0]
            form.style.display = 'block';
            form.getElementsByTagName('select')[0].focus();
        }
    }, false);
