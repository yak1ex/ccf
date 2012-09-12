$(function() {
	var status = {};
	var idxmap = {};
	var idmap = {};
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
	// Status updater
	var updater = function() {
		var idx = $('#result').tabs('option', 'selected');
		if(idx != 0 && status[idxmap[idx]].status != 4) {
			console.log('IDX:' + idx + 'IDXMAP:' + idxmap[idx] + 'ID:' + status[idxmap[idx]].id);
			$.ajax({
				url: 'ccf.cgi',
				data: { command: 'status', id: status[idxmap[idx]].id },
				dataType: 'json'
			}).done(function(msg) {
				status[idmap[msg.id]].status = msg.status;
			});
			$('#result').tabs('load', idx);
			setTimeout(updater, 1000);
		}
	};
	// Invoke
	// TODO: actual implementation
	$('#form').submit(function() {
		$('#result').tabs('destroy');
		$('#result').tabs();
		$.each($('.ctypes:checked'), function(idx, obj) {
            $.ajax({
				url: 'ccf.cgi?command=invoke&'
                     + $('#source').serialize()
                     + '&type=' + obj.name
                     + '&execute=' + ($('#compile:checked').length == 0 ? 'true' : 'false'),
                dataType: 'json'
			}).done(function(msg) {
				status[obj.name].id = msg.id;
				idmap[msg.id] = obj.name;
				$('#result').tabs('url', status[obj.name].idx, 'ccf.cgi?command=status&id=' + msg.id);
			});
			$('#result').tabs('add', 'ccf.dummy.html', obj.name);
			status[obj.name] = { status: 0, idx: $('#result').tabs('length')-1 };
			idxmap[$('#result').tabs('length')-1] = obj.name;
		});
		return false;
	});
	$('#result').tabs();
	$('#result').bind("tabsselect", function(event, ui) {
		setTimeout(updater, 1000);
		return true;
	});
});
