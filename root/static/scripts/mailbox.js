window.addEvent('load', function() {
    var start_time = (new Date()).getTime();
    var droppables = $('folder_tree').getElements('.folder');

    function start (event) {
        var target = event.target || event.srcElement;
        while (target && target.nodeType == 3) target = target.parentNode;

        if (target.tagName.toLowerCase() == 'img' && target.id && target.id.indexOf('icon_') == 0) {
            var message = target;
            message.style.position = 'fixed';
            message.style.left = event.clientX + 'px';
            message.style.top = event.clientY + 'px';

            add_drag_and_drop(message, droppables);

            // stop bubbling, so the browser's image drag&drop doesn't kick in
            if (event.stopPropagation) event.stopPropagation();
            else event.cancelBubble = true;

            if (event.preventDefault) event.preventDefault();
            else event.returnValue = false;
        }
    }

    if (document.addEventListener) document.addEventListener('mousedown', start, false);
    else document.attachEvent('onmousedown', start);
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

    document.addEvents({mousemove: drag, mouseup: drop});
}
