var droppables;
var current_message;

window.addEvent('load', function() {
    var start_time = (new Date()).getTime();
    var selected = [];
    droppables = $('folder_tree').getElements('.folder');
    var loading_message = $('message_view').innerHTML;
    var cancelled = false;

    function get_target_node(event) {
        var target = event.target || event.srcElement;
        while (target && target.nodeType == 3) target = target.parentNode;
        return target;
    }

    function start(event) {
        var target = get_target_node(event);
        var tag_name = target.tagName.toLowerCase();

        if (tag_name == 'img' && target.id && target.id.indexOf('icon_') == 0) {
            if (! selected.length) selected.push(target.parentNode.parentNode);
            add_drag_and_drop(target, event, droppables, selected);
            stop_propagation(event);
        }
        else if (tag_name == 'td' && target.parentNode.id && target.parentNode.id.indexOf('message_') == 0) {
            if (! selected.length) selected.push(target.parentNode);
            var icon = target.parentNode.getElementsByTagName('img')[0];
            add_drag_and_drop(icon, event, droppables, selected);
            stop_propagation(event);
        }
        else if (tag_name == 'a' && target.id && target.id.indexOf('link_') == 0) {
            if (! selected.length) selected.push(target.parentNode.parentNode);
            var icon = target.parentNode.parentNode.getElementsByTagName('img')[0];
            cancelled = false;
            setTimeout(function () { if (!cancelled) add_drag_and_drop(icon, event, droppables, selected); }, 200);
            stop_propagation(event);
        }
    }

    function show_message(target) {
        var uid = target.id.replace('link_', '');
        $(target.parentNode.parentNode).addClass('seen');
        $('message_view').innerHTML = loading_message;
        $('loading_message').style.display = 'block';
        $('help_message').style.display = 'none';
        $('message_view').style.top = '30%';
        $('content').addClass('message_display');
        current_message = target.parentNode.parentNode;
        var myHTMLRequest = new Request.HTML({
            onSuccess: function(responseTree, responseElements, responseHTML, responseJavaScript) {
                var parsed = responseHTML.match(/([\s\S]*?)<div[^>]*>([\s\S]*)<\/div>/);
                $('message_view').innerHTML = parsed[2];
                update_foldertree(parsed[1], responseTree);
            }
        }).get(target.href + "?layout=ajax");
    }

    function handle_click(event) {
        var target = get_target_node(event);
        var tagname = target.tagName.toLowerCase();

        if (tagname == 'a' && target.id && target.id.indexOf('link_') == 0) {
            cancelled = true;
            show_message(target);
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

    add_event_listener('mousedown', start, false);
    add_event_listener('click', handle_click, false);
    add_event_listener('keyup', function (event) {
            switch (event.keyCode) {
                case 37: // left
                    var previous = current_message.previousSibling;
                    if (previous && previous.nodeType != 1) previous = previous.previousSibling;
                    if (! previous || ! previous.id) { // first row is the group header
                        var prev_group = current_message.parentNode.previousSibling;
                        if (prev_group) {
                            var prev_messages = prev_group.getElementsByTagName('tr');
                            previous = prev_messages[prev_messages.length - 1];
                        }
                    }
                    if (previous && previous.id) // first row of the table is table header
                        show_message(document.getElementById(previous.id.replace('message', 'link'))); //left
                    break;
                case 39: // right
                    var next = current_message.nextSibling;
                    if (next && next.nodeType != 1) next = next.nextSibling;
                    if (! next) {
                        var next_group = current_message.parentNode.nextSibling;
                        if (next_group)
                            next = next_group.getElementsByTagName('tr')[1]; // first row is the group header
                    }
                    if (next)
                        show_message(document.getElementById(next.id.replace('message', 'link'))); //left
                    break;
            }
        }, false);

    var length = 250;
    fetch_new_rows(length, length);
});

function fetch_new_rows(start_index, length) {
    var start = 'start=' + start_index
    var href = location.search.match(/start=/) ? location.href.replace(/start=\d+/, start) : (location.href.match(/\?/) ? location.href + '&' + start : location.href + '?' + start);

    new Request({url: href + ';layout=ajax', onSuccess: function(responseText, responseXML) {
        // this hack is presented to you by Microsoft
        var dummy = document.createElement('span');
        dummy.innerHTML = '<table>' + responseText.match(/<table[^>]+id="message_list"[^>]*>([\S\s]*)<\/table>/)[1] + '</table>'; // responseXML.getElementById doesn't work in IE
        var new_rows = dummy.firstChild;

        while (new_rows.firstChild.nodeType == 3)
            new_rows.removeChild(new_rows.firstChild);
        new_rows.removeChild(new_rows.firstChild);

        dummy.innerHTML = new_rows.parentNode.innerHTML;
        new_rows = dummy.firstChild.nodeType == 1 ? dummy.firstChild : dummy.firstChild.nextSibling;

        var child = new_rows.firstChild;
        while (child) { // remove text and comment nodes as we are only really interested in tbodys
            var next = child.nextSibling;
            if (child.nodeType != 1) {
                new_rows.removeChild(child);
            }
            child = next;
        }

        if (new_rows.childNodes.length && new_rows.firstChild.childNodes.length) { // IE has an empty tbody if now rows were added
            var message_list = document.getElementById('message_list');
            for (var i = 0; i < new_rows.childNodes.length ; i++)
                message_list.appendChild(new_rows.childNodes[i].cloneNode(true));
            fetch_new_rows(start_index + length, length);
        }
    }}).send();
}

function update_foldertree(responseText, responseXML) {
    var folder_tree = responseText.match(/<ul[^>]*id="folder_tree"[^>]*>([\s\S]*)<\/ul>/i)[1]; // responseXML.getElementById doesn't work in IE
    document.getElementById('folder_tree').innerHTML = folder_tree;
    droppables = $('folder_tree').getElements('.folder');
}

function add_drag_and_drop(message, event, droppables, selected) {
    var overed_prev;
    var droppables_positions = {};
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
