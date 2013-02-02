window.addEvent('load', function() {
    new Form.Validator.Inline($('compose_form'), {
        stopOnFailure : true,
        useTitles: true,
        errorPrefix: "",
    });
});
