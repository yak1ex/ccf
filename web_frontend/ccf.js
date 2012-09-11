$(function() {
	// Init
	// TODO: Select all and deselect all
	$.ajax({
		url: 'ccf.cgi',
		data: { command: 'list' },
		dataType: 'json'
	}).done(function(msg) {
		$.each(msg, function(key, value) {
			$('#compiler_types').append('<input type="checkbox" class="ctypes" name="' + key + '">[' + key + '] ' + value + '<br>');
		});
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
