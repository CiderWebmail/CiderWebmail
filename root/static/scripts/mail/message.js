function toggleHeader(node, on) {
    node.parentNode.parentNode.parentNode.getElementsByTagName('pre')[0].style.display = on ? '' : 'none';
}

function load_subpart(target) {
    var subpart_uri = target.href;
    var target_div = $(target.parentNode.parentNode); //the body_part div

    var myHTMLRequest = new Request.HTML({
        onSuccess: function(responseTree, responseElements, responseHTML, responseJavaScript) {
            target_div.innerHTML = responseHTML;
        },
        url: target.href
    }).get({ 'layout': 'ajax' });
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
            case 82: // 'r'
                window.open($$('.reply')[0].href);
                break;
            case 70: // 'f'
                window.open($$('.forward')[0].href);
                break;
        }
    }, false);
