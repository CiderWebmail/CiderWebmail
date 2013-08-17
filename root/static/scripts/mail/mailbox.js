var droppables;
var current_message;
var loading_message;

function get_target_node(event) {
    var target = event.target || event.srcElement;
    while (target && target.nodeType == 3) target = target.parentNode;
    return target;
}

function show_message(target) {
    var messages_pane = document.getElementById('messages_pane');

    document.getElementById('message_view').innerHTML = loading_message;
    document.getElementById('loading_message').style.display = 'block';
    document.getElementById('help_message').style.display = 'none';

    if (! document.getElementById('content').classList.contains('message_display')) {
        var message_divider_top = Cookie.read('message_divider_message_display_top');
        document.getElementById('content').classList.add('message_display');
        messages_pane.style.bottom = message_divider_top ? document.getElementById('messages_pane').parentNode.offsetHeight - message_divider_top + 'px' : '70%';
        document.getElementById('message_view').style.top     = message_divider_top ? message_divider_top + 'px' : '30%';
        document.getElementById('message_divider').style.top  = message_divider_top ? message_divider_top + 'px' : '30%';
    }

    if (current_message)
        current_message.classList.remove('active');

    current_message = target.parentNode.parentNode;
    current_message.classList.add('seen');
    current_message.classList.add('active');

    if (current_message.offsetTop + current_message.offsetHeight > messages_pane.scrollTop + messages_pane.offsetHeight)
        messages_pane.scrollTop = current_message.offsetTop + current_message.offsetHeight - messages_pane.offsetHeight;

    if (current_message.offsetTop < messages_pane.scrollTop)
        messages_pane.scrollTop = current_message.offsetTop;

    var myHTMLRequest = new HTMLRequest({
        onSuccess: function(responseXML) {
            document.getElementById('message_view').innerHTML
                = responseXML.getElementById('content').innerHTML;
            update_foldertree(responseXML);
        },
        url: target.href
    }).send({ 'layout': 'ajax' });
}

function show_previous_message() {
    var previous = current_message.previousSibling;

    if (previous && previous.nodeType != 1) previous = previous.previousSibling;

    if (! previous || ! previous.id) { // first row is the group header
        var prev_group = current_message.parentNode.previousSibling;
        if (prev_group) {
            var prev_messages = prev_group.getElementsByTagName('tr');
            previous = prev_messages[prev_messages.length - 1];
        }
    }

    if (previous && previous.id) { // first row of the table is table header
        show_message(document.getElementById(previous.id.replace('message', 'link'))); //left
        return 1;
    }

    //reset view to the very top to show group header if no previous message is found
    //and reset the message to the default
    messages_pane.scrollTop = 0;
    reset_message_view();

    
    return 0;
}

function show_next_message() {
    var next = current_message.nextSibling;

    if (next && next.nodeType != 1) next = next.nextSibling;

    if (! next) {
        var next_group = current_message.parentNode.nextSibling;
        if (next_group && next_group.nodeType != 1) next_group = next_group.nextSibling;
        if (next_group)
            next = next_group.getElementsByTagName('tr')[1]; // first row is the group header
    }

    if (next) {
        show_message(document.getElementById(next.id.replace('message', 'link'))); //left
        return 1;
    }

    return 0;
}

function delete_message(icon) {
    new Request({url: icon.parentNode.href, onSuccess: update_foldertree, headers: {'X-Request': 'AJAX'}}).send();

    var group = icon.parentNode.parentNode.parentNode.parentNode;
    group.removeChild(icon.parentNode.parentNode.parentNode);
    if (group.getElementsByTagName('tr').length == 1)
        group.parentNode.removeChild(group);
}

window.addEventListener('load', function() {
    var selected = [];
    droppables = document.getElementById('folder_tree').querySelectorAll('.folder');
    loading_message = document.getElementById('message_view').innerHTML;
    var cancelled = false;

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

    function handle_click(event) {
        var target = get_target_node(event);
        var tagname = target.tagName.toLowerCase();

        if (tagname == 'a' && target.id && target.id.indexOf('link_') == 0) {
            cancelled = true;
            show_message(target);
            stop_propagation(event);
        }
        else if (tagname == 'img' && target.id && target.id.indexOf('delete_') == 0) {
            delete_message(target);
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
                    target.classList.remove('selected');
                    selected.erase(target);
                }
                else {
                    target.addClass('selected');
                    selected.push(target);
                }
            }
        }
    }

    document.addEventListener('mousedown', start, false);
    document.addEventListener('click', handle_click, false);
    document.addEventListener('keyup', function (event) {
            if (event.target && event.target.nodeType == 1 && (event.target.nodeName == 'input' || event.target.nodeName == 'textarea'))
                return;

            switch (event.keyCode) {
                case 37: // left
                case 75: // k
                    show_previous_message();
                    break;
                case 39: // right
                case 74: // j
                    show_next_message();
                    break;
                case 32: // space bar
                    document.getElementById('message_view').scrollTop = (document.getElementById('message_view').scrollTop + 250);
                    break;
                case 38: // arrow up
                    document.getElementById('message_view').scrollTop = (document.getElementById('message_view').scrollTop - 25);
                    break;
                case 40: // arrow down
                    document.getElementById('message_view').scrollTop = (document.getElementById('message_view').scrollTop + 25);
                    break;
                case 191: // '/' key
                    var filter = document.getElementById('filter');
                    filter.focus();
                    filter.setSelectionRange(0, filter.value.length);
                    break;
            }
        }, false);

    fetch_new_rows(100, 100);
}, false);

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

            var messages_pane = document.getElementById('messages_pane');
            var fetcher = function (event) {
                if (messages_pane.scrollTop > messages_pane.scrollHeight - messages_pane.offsetHeight * 3) {
                    messages_pane.removeEvent('scroll', fetcher);
                    var length = 100;
                    fetch_new_rows(start_index + length, length);
                }
            };
            messages_pane.addEventListener('scroll', fetcher, false);
        }
        else {
            document.getElementById('fetching_message').style.display = 'none';
        }
    }}).send();
}

function update_foldertree(responseXML) {
    var new_folder_tree = document.importNode(responseXML.getElementById('folder_tree'));
    var new_foldertree_timestamp = new_folder_tree.getAttribute('data-timestamp');
    document.title = responseXML.getElementById('unseen').firstChild.data;

    var folder_tree = document.getElementById('folder_tree');

    //only update the foldertree if the response comes in the correct order. sometimes a request takes longer than others.
    if (new_foldertree_timestamp > document.getElementById('folder_tree').getAttribute('data-timestamp')) { 
        folder_tree.parentNode.replaceChild(new_folder_tree, folder_tree);
    } 

    droppables = document.getElementById('folder_tree').querySelectorAll('.folder');

}

function add_drag_and_drop(message, event, droppables, selected) {
    if (touch_enabled) { return; }

    var overed_prev;
    var droppables_positions = {};
    [].forEach.call(droppables, function (droppable) {
        droppables_positions[droppable.title] = get_coordinates(droppable);
    });

    function drag(event) {
        var overed;
        [].forEach.call(droppables, function (el) {
            el = droppables_positions[el.title];
            if (event.client.x > el.left && event.client.x < el.right && event.client.y < el.bottom && event.client.y > el.top)
                overed = el;
        });

        if (overed_prev != overed) {
            if (overed_prev) {
                overed_prev.classList.remove('hover');
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

        if (overed_prev) {
            selected.forEach(function (message) {
                var uid = message.id.replace('message_', '');
                var href = location.href.replace(/\/?(\?.*)?$/, '');
                new Request({url: href + "/" + uid + "/move?target_folder=" + overed_prev.title, onSuccess: update_foldertree, headers: {'X-Request': 'AJAX'}}).send();

                var tbody = message.parentNode
                tbody.removeChild(message);

                var children = 0;
                for (var i = 0; i < tbody.childNodes.length; i++)
                    if (tbody.childNodes[i].nodeType == 1) children++;
                if (children == 1)
                    tbody.parentNode.removeChild(tbody);
            });
        }

        selected.forEach(function(message) {
            message.classList.remove('selected');
        });
        selected.splice(0, selected.length);
    }

    var dragger = document.createElement('ul');
    selected.forEach(function (message) {
        var li = document.createElement('li');
        li.innerHTML = message.querySelector('td.subject a').innerHTML;
        dragger.appendChild(li);
    });

    dragger.className = 'dragger';
    dragger.style.left = event.clientX + 'px';
    dragger.style.top  = event.clientY + 'px';

    document.body.appendChild(dragger);

    document.addEventListener('mousemove', drag, false);
    document.addEventListener('mouseup', drop, false);
}
