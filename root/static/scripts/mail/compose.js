window.addEvent('load', function() {
    new Form.Validator.Inline($('compose_form'), {
        stopOnFailure : true,
        useTitles: true,
        errorPrefix: "",
    });
});

window.addEvent("domready", function() {
    var tagify = new mooTagify(document.id("tagWrap"), null, {
        availableOptions: ['bar','barman','barmaid','bartender','FooBar','Gay Bar','crowbar','this','I like this'],
        tagEls: 'span.btn.btn-mini',
        closeEls: 'button.close.btn-small.remove-tag',
        autoSuggest: true,
        tags: 'foo,bar,this rocks',
        /* tags: function() {
            return this.listTags.get('value').clean();
        },*/
        // persist: false,
        // addOnBlur: false, // only works via enter to add.
        onInvalidTag: function(invalidTag) {
            console.log(invalidTag + " was rejected due to length");
        },
        onLimitReached: function(rejectedTag) {
            console.log(rejectedTag + " was not added, you have reached the maximum allowed tags count of " + this.options.maxItemCount);
        }
    });

    document.id("getTags").addEvent("click", function() {
        console.log(tagify.getTags(), tagify.getTags().join(","));
    });

});

