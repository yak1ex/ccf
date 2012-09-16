var tabopts = { spinner: '', cache: true };
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
		var keys = $.map(msg, function(value, key) { return key; }).sort();
		$.each(keys, function(idx, key) {
			$('#compiler_types').append('<input type="checkbox" class="ctypes" id="' + key + '" name="' + key + '"><label for="' + key + '">[' + key + '] ' + msg[key] + '</label>' + (idx % 2 == 1 ? '<br>' : ''));
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
        $('.selector').button();
        $('#selectall').click(function(e) {
			$('.ctypes:not(:checked)').click();
		});
        $('#deselectall').click(function(e) {
			$('.ctypes:checked').click();
		});
		$('#input-container').addClass('ui-widget ui-widget-content ui-corner-all');
		$('#source-label').addClass('ui-widget-header ui-corner-all');
		$('#source').addClass('ui-corner-all');
	});
	// Status updater
	var updater = function() {
		var idx = $('#result').tabs('option', 'selected');
		if(idx != 0) {
			if(status[idxmap[idx]].status != 4) {
				$.ajax({
					url: 'ccf.cgi',
					data: { command: 'status', id: status[idxmap[idx]].id },
					dataType: 'json'
				}).done(function(msg) {
					status[idmap[msg.id]].status = msg.status;
				});
				$('#result').tabs('load', idx);
				setTimeout(updater, 1000);
			} else {
				$('#result').tabs('load', idx);
				status[idmap[msg.id]].status = 5;
			}
		}
	};
	// Invoke
	// TODO: actual implementation
	$('#form').submit(function() {
		$('#result').tabs('destroy');
		$('#result').tabs(tabopts);
		$.each($('.ctypes:checked'), function(idx, obj) {
            $.ajax({
            	type: 'POST',
				url: 'ccf.cgi',
				data: {
					command: 'invoke',
					source: $('#source').val(),
					type: obj.name,
					execute: ($('#compile:checked').length == 0 ? 'true' : 'false'),
				},
                dataType: 'json'
			}).done(function(msg) {
				status[obj.name].id = msg.id;
				idmap[msg.id] = obj.name;
				$('#result').tabs('url', status[obj.name].idx, 'ccf.cgi?command=show&id=' + msg.id);
			});
			$('#result').tabs('add', 'ccf.dummy.html', obj.name);
			status[obj.name] = { status: 0, idx: $('#result').tabs('length')-1 };
			idxmap[$('#result').tabs('length')-1] = obj.name;
		});
		return false;
	});
	$('#result').tabs(tabopts);
	$('#result').bind("tabsselect", function(event, ui) {
		setTimeout(updater, 1000);
		return true;
	});
});
