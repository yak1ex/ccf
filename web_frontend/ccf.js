$(function() {
	// Init
	// TODO: Select all and deselect all
	$.ajax({
		url: 'ccf.cgi',
		data: { command: 'list' },
		dataType: 'json'
	}).done(function(msg) {
        // Setup compiler types
		$.each(msg, function(key, value) {
			$('#compiler_types').append('<input type="checkbox" class="ctypes" id="' + key + '" name="' + key + '"><label for="' + key + '">[' + key + '] ' + value + '</label><br>');
		});
        // Apply jQuery theme and add icons
		$('input:checkbox').button({ icons: { primary: 'ui-icon-minus' } })
        .change(function(e) {
			if($(this).button('option', 'icons').primary == 'ui-icon-minus') {
				$(this).button('option', 'icons', { primary: 'ui-icon-plus' });
			} else {
				$(this).button('option', 'icons', { primary: 'ui-icon-minus' });
			}
		});
        // Apply jQuery theme
        // TODO: Use table?
		$('#input-container').addClass('ui-widget ui-widget-content ui-corner-all');
		$('#source-label').addClass('ui-widget-header ui-corner-all');
		$('#source').addClass('ui-corner-all');
	});
	// Invoke
	// TODO: actual implementation
	$('#form').submit(function() {
		$('#result').tabs('destroy');
		$('#result').tabs();
		$.each($('.ctypes:checked'), function(idx, obj) {
/*			window.alert(
				'command=invoke&' + $('#source').serialize() + '&' +
				'type=' + obj.name + '&' +
				'execute=' + ($('#compile:checked').length == 0 ? 'true' : 'false')
			);*/
			$('#result').tabs('add', 'ccf.dummy.html', obj.name);
		});
		return false;
	});
	$('#result').tabs();
});
