window.addEvent('load', function() {
    var messages = document.getElementById('messages_pane').getElementsByTagName('img');

    var selection = (Browser.Engine.trident) ? 'selectstart' : 'mousedown';
    var droppables = $$('.folder');
    var overed_prev;

    for (var index = 0; index < messages.length; index++) {
        var message = messages[index];

        var drag = function(event) {
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
        };

        var drop = function(event) {
            document.removeEvent('mousemove', drag);
            document.removeEvent('mouseup', drop);
            message.style.position = '';
            message.style.left = '';
            message.style.top = '';

            if (! overed_prev) return;
            var uid = message.id.replace('icon_', '');
            document.location.href += "/" + uid + "/move?target_folder=" + overed_prev.title;
        };

        var start = function (event) {
            message.style.position = 'fixed';
            message.style.left = event.client.x + 'px';
            message.style.top = event.client.y + 'px';

            document.addEvents({mousemove: drag, mouseup: drop});
            return false; // stop bubbling, so the browser's image drag&drop doesn't kick in
        };

        message.addEvent('mousedown', start);
    }
});
