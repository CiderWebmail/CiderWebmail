window.addEvent('load', function() {
    var start_time = (new Date()).getTime();
    var droppables = $('folder_tree').getElements('.folder');

    function stop_propagation(event) {
        if (event.stopPropagation) event.stopPropagation();
        event.cancelBubble = true;

        if (event.preventDefault) event.preventDefault();
        else event.returnValue = false;
    }

    function get_target_node(event) {
        var target = event.target || event.srcElement;
        while (target && target.nodeType == 3) target = target.parentNode;
        return target;
    }

    function start(event) {
        var target = get_target_node(event);

        if (target.tagName.toLowerCase() == 'img' && target.id && target.id.indexOf('icon_') == 0) {
            var message = target;
            message.style.position = 'fixed';
            message.style.left = event.clientX + 'px';
            message.style.top = event.clientY + 'px';

            add_drag_and_drop(message, droppables);
            stop_propagation(event);
        }
    }

    function load_mail(event) {
        var target = get_target_node(event);

        if (target.tagName.toLowerCase() == 'a' && target.id && target.id.indexOf('link_') == 0) {
            var uid = target.id.replace('link_', '');
            var myHTMLRequest = new Request.HTML({update: 'message_view'}).get(target.href + "?layout=ajax");
            stop_propagation(event);
        }
    }

    if (document.addEventListener) document.addEventListener('mousedown', start, false);
    else document.attachEvent('onmousedown', start);

    if (document.addEventListener) document.addEventListener('click', load_mail, false);
    else document.attachEvent('onclick', load_mail);
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
