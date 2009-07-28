var droppables;

window.addEvent('load', function() {
    var start_time = (new Date()).getTime();
    var selected = new Array();
    droppables = $('folder_tree').getElements('.folder');
    var loading_message = $('message_view').innerHTML;

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
            if (! selected.length) selected.push(target.parentNode.parentNode);
            add_drag_and_drop(target, event, droppables, selected);
            stop_propagation(event);
        }
        else if (target.tagName.toLowerCase() == 'td' && target.parentNode.id && target.parentNode.id.indexOf('message_') == 0) {
            if (! selected.length) selected.push(target.parentNode);
            var icon = target.parentNode.getElementsByTagName('img')[0];
            add_drag_and_drop(icon, event, droppables, selected);
            stop_propagation(event);
        }
    }

    function handle_click(event) {
        var target = get_target_node(event);
        var tagname = target.tagName.toLowerCase();

        if (tagname == 'a' && target.id && target.id.indexOf('link_') == 0) {
            var uid = target.id.replace('link_', '');
            $('message_view').innerHTML = loading_message;
            $('loading_message').style.display = 'block';
            $('help_message').style.display = 'none';
            $('message_view').style.top = '30%';
            $('content').addClass('message_display');
            var myHTMLRequest = new Request.HTML({
                onSuccess: function(responseTree, responseElements, responseHTML, responseJavaScript) {
                    $('message_view').innerHTML = responseHTML;
                }
            }).get(target.href + "?layout=ajax");
            stop_propagation(event);
        }
        else if (tagname == 'img' && target.id && target.id.indexOf('delete_') == 0) {
            var uid = target.id.replace('delete_', '');
            new Request({url: target.parentNode.href, onSuccess: update_foldertree}).send();
            var group = target.parentNode.parentNode.parentNode.parentNode;
            group.removeChild(target.parentNode.parentNode.parentNode);
            if (group.childNodes.length == 1)
                group.parentNode.removeChild(group);
            stop_propagation(event);
        }
        else {
            while (tagname != 'body' && tagname != 'tr') {
                if (tagname == 'a') break; // let links continue to work

                target = target.parentNode;
                if (target.nodeType != 1) break; // no use continuing here
                tagname = target.tagName.toLowerCase();
            }

            if (tagname == 'tr' && target.id && target.id.indexOf('message_') == 0) {
                if (target.hasClass('selected')) {
                    target.removeClass('selected');
                    selected.erase(target);
                }
                else {
                    target.addClass('selected');
                    selected.push(target);
                }
            }
        }
    }

    if (document.addEventListener) document.addEventListener('mousedown', start, false);
    else document.attachEvent('onmousedown', start);

    if (document.addEventListener) document.addEventListener('click', handle_click, false);
    else document.attachEvent('onclick', handle_click);

    if (location.search.match(/start=/)) {
        /start=(\d+)/.exec(location.search);
        var start_index = parseInt(RegExp.$1);
        /length=(\d+)/.exec(location.search);
        var length = parseInt(RegExp.$1);
        start_index += length;
        fetch_new_rows(start_index, length)
    }
});

function fetch_new_rows(start_index, length) {
        var href = location.href.replace(/start=\d+/, 'start=' + start_index);

        new Request({url: href + ';layout=ajax', onSuccess: function(responseText, responseXML) {
            var new_rows = responseXML.getElementById('message_list');
            while (new_rows.firstChild.nodeType == 3)
                new_rows.removeChild(new_rows.firstChild);
            new_rows.removeChild(new_rows.firstChild);

            // this hack is presented to you by Microsoft
            var dummy = document.createElement('span');
            dummy.innerHTML = new_rows.parentNode.innerHTML;
            new_rows = dummy.firstChild.nodeType == 1 ? dummy.firstChild : dummy.firstChild.nextSibling;

            if (new_rows.childNodes.length) {
                message_list = document.getElementById('message_list');
                for (var i = 0; i < new_rows.childNodes.length ; i++)
                    message_list.appendChild(new_rows.childNodes[i].cloneNode(true));
                fetch_new_rows(start_index + length, length);
            }

            document.removeChild(dummy);
        }}).send();
}

function update_foldertree(responseText, responseXML) {
    var folder_tree = responseText.match(/<ul[^>]*id="folder_tree"[^>]*>([\s\S]*)<\/ul>/i)[1]; // responseXML.getElementById doesn't work in IE
    document.getElementById('folder_tree').innerHTML = folder_tree;
    droppables = $('folder_tree').getElements('.folder');
}

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
            var href = location.href.replace(/\/?(\?.*)?$/, '');
            new Request({url: href + "/" + uid + "/move?target_folder=" + overed_prev.title, onSuccess: update_foldertree}).send();

            var tbody = message.parentNode
            tbody.removeChild(message);

            var children = 0;
            for (var i = 0; i < tbody.childNodes.length; i++)
                if (tbody.childNodes[i].nodeType == 1) children++;
            if (children == 1)
                tbody.parentNode.removeChild(tbody);
        });

        selected.splice(0, selected.length);
    }

    var dragger = document.createElement('ul');
    selected.each(function (message) {
        var li = document.createElement('li');
        li.innerHTML = $(message).getElements('td.subject a')[0].innerHTML;
        dragger.appendChild(li);
    });

    dragger.className = 'dragger';
    dragger.style.left = event.clientX + 'px';
    dragger.style.top  = event.clientY + 'px';

    document.body.appendChild(dragger);

    document.addEvents({mousemove: drag, mouseup: drop});
}

function toggleHeader(node, on) {
    var header = node.parentNode.parentNode.nextSibling;
    if (header.nodeType != 1) header = header.nextSibling;
    header.getElementsByTagName('pre')[0].style.display = on ? '' : 'none';
}

function open_in_new_window(link) {
    window.open(link);
    return false;
}
