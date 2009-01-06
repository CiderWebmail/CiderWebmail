window.addEvent('load', function() {
    var messages = document.getElementById('messages_pane').getElementsByTagName('img');

    var droppables = $$('.folder');

    for (var index = 0; index < messages.length; index++) {
        add_drag_and_drop(messages[index], droppables);
    }
});

function add_drag_and_drop(message, droppables) {
    var overed_prev;

    function drag(event) {
        var overed = droppables.filter(function (el) {
                el = el.getCoordinates();
                return (event.client.x > el.left && event.client.x < el.right && event.client.y < el.bottom && event.client.y > el.top);
            }).getLast();

        if (overed_prev != overed) {
            if (overed_prev) {
                overed_prev.removeClass('hover');
            }
            overed_prev = overed;
            if (overed){
                overed.addClass('hover');
            }
        }
        message.style.left = event.client.x + 'px';
        message.style.top = event.client.y + 'px';
    }

    function drop(event) {
        document.removeEvent('mousemove', drag);
        document.removeEvent('mouseup', drop);
        message.style.position = '';
        message.style.left = '';
        message.style.top = '';

        if (! overed_prev) return;
        var uid = message.id.replace('icon_', '');
        document.location.href += "/" + uid + "/move?target_folder=" + overed_prev.title;
    }

    function start (event) {
        message.style.position = 'fixed';
        message.style.left = event.clientX + 'px';
        message.style.top = event.clientY + 'px';

        document.addEvents({mousemove: drag, mouseup: drop});

        // stop bubbling, so the browser's image drag&drop doesn't kick in
        if (event.stopPropagation) event.stopPropagation();
        else event.cancelBubble = true;

        if (event.preventDefault) event.preventDefault();
        else event.returnValue = false;
    }

    if (message.addEventListener) message.addEventListener('mousedown', start, false);
    else message.attachEvent('onmousedown', start);
}
