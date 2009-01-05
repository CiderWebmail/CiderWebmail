window.addEvent('domready', function() {
    var messages = $$('table.message_list tr td.icon img');

    messages.each(function (message, index) {
        var message_drag = message.makeDraggable({
            droppables: '.folder',

            onDrop: function(element, droppable){
                if (! droppable) return;
                var uid = message.id.replace('icon_', '');
                var folder = droppable.title;
                document.location.href = document.location.href + "/" + uid + "/move?target_folder=" + folder
            },

            onEnter: function(element, droppable){
                droppable.addClass('hover');
            },

            onLeave: function(element, droppable){
                droppable.removeClass('hover');
            }
        });
    });
});
