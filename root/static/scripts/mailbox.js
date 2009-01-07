window.addEvent('load', function() {
    var start_time = (new Date()).getTime();
    var droppables = $('folder_tree').getElements('.folder');
    var selected = new Array();

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
            add_drag_and_drop(target, event, droppables, selected);
            stop_propagation(event);
        }
    }

    function load_mail(event) {
        var target = get_target_node(event);
        var tagname = target.tagName.toLowerCase();

        if (tagname == 'a' && target.id && target.id.indexOf('link_') == 0) {
            var uid = target.id.replace('link_', '');
            $('message_view').innerHTML = '<p>loading message...</p>';
            var myHTMLRequest = new Request.HTML({update: 'message_view'}).get(target.href + "?layout=ajax");
            stop_propagation(event);
        }
        else {
            while (tagname != 'body' && tagname != 'tr') {
                if (tagname == 'a') break; // let links continue to work

                target = target.parentNode;
                if (target.nodeType != 3) break; // no use continuing here
                tagname = target.tagName.toLowerCase();
            }

            if (tagname == 'tr' && target.id && target.id.indexOf('message_') == 0) {
                target.addClass('selected');
                selected.push(target);
            }
        }
    }

    if (document.addEventListener) document.addEventListener('mousedown', start, false);
    else document.attachEvent('onmousedown', start);

    if (document.addEventListener) document.addEventListener('click', load_mail, false);
    else document.attachEvent('onclick', load_mail);
});

function add_drag_and_drop(message, event, droppables, selected) {
    var overed_prev;
    var droppables_positions = new Object();
    droppables.each(function (droppable) {
        droppables_positions[droppable.title] = droppable.getCoordinates();
    });

    function drag(event) {
        var overed = droppables.filter(function (el) {
                el = droppables_positions[el.title];
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
        dragger.style.left = event.client.x + 'px';
        dragger.style.top  = event.client.y + 'px';
    }

    function drop(event) {
        document.removeEvent('mousemove', drag);
        document.removeEvent('mouseup', drop);

        dragger.parentNode.removeChild(dragger);

        if (! overed_prev) return;

        selected.each(function (message) {
            var uid = message.id.replace('message_', '');
            var move_request = new Request.HTML({url: document.location.href + "/" + uid + "/move?target_folder=" + overed_prev.title}).send();
            message.parentNode.removeChild(message);
        });

        selected.splice(0, selected.length);
    }

    var dragger = document.createElement('ul');
    selected.each(function (message) {
        var li = document.createElement('li');
        li.innerHTML = message.getElements('td.subject a')[0].innerHTML;
        dragger.appendChild(li);
    });

    dragger.className = 'dragger';
    dragger.style.left = event.clientX + 'px';
    dragger.style.top  = event.clientY + 'px';

    document.body.appendChild(dragger);

    document.addEvents({mousemove: drag, mouseup: drop});
}
