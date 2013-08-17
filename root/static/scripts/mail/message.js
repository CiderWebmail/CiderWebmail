function toggleHeader(node, on) {
    node.parentNode.parentNode.parentNode.getElementsByTagName('pre')[0].style.display = on ? '' : 'none';
}

function load_subpart(target) {
    var subpart_uri = target.href;
    var target_div = target.parentNode.parentNode; //the body_part div

    var myHTMLRequest = new HTMLRequest({
        onSuccess: function(responseXML) {
            target_div.innerHTML = responseXML.getElementsByTagName('body')[0].innerHTML;
        },
        url: target.href
    }).send({ 'layout': 'ajax' });
}

function toggle_important(target) {
    new Request({
        url: target.href,
        onSuccess: function(responseTree, responseElements, responseHTML, responseJavaScript) {
            document.getElementById('important_flag').src = responseTree;
        },
        headers: {'X-Request': 'AJAX'}
    }).send();
}


function resize_iframe(target) {
    target.style.height = '1px'; // otherwise some browsers (chrome...) report scrollHeight as 600px (as set in message.css)
                                 // this way the report the actual scroll height
                                 
    target.style.height = target.contentWindow.document.body.scrollHeight + 'px';
}

document.addEventListener('keyup', function (event) {
        if (event.target && event.target.nodeType == 1 && (event.target.nodeName.toLowerCase() == 'input' || event.target.nodeName == 'textarea'))
            return;
        switch (event.keyCode) {
            case 77: // 'm'
                var form = document.getElementById('content').querySelector('form.move_message')
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
            case 82: // 'r'
                window.open(document.querySelector('.reply').href);
                break;
            case 70: // 'f'
                window.open(document.querySelector('.forward').href);
                break;
        }
    }, false);
