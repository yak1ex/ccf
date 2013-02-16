// ccf.js - Javascript source for C++ Compiler Farm client
//     Written by Yak! <yak_ex@mx.scn.tv>
//
//     Distributed under the Boost Software License, Version 1.0.
//     (See accompanying file LICENSE_1_0.txt or copy at
//      http://www.boost.org/LICENSE_1_0.txt)

var tabopts = {
	beforeLoad: function( event, ui ) {
		if ( ui.tab.data( "loaded" ) ) {
			event.preventDefault();
			return;
		}

		ui.jqXHR.success(function() {
			ui.tab.data( "loaded", true );
		});
	}
};
$(function() {
    var editor = ace.edit("source");
    editor.setTheme("ace/theme/eclipse");
    editor.getSession().setMode("ace/mode/c_cpp");
	editor.commands.addCommand({
		name: 'execute-compiler',
		bindKey: 'F5',
		exec: function(editor) {
			$('#form').submit();
		},
		readonly: false
	});
	editor.commands.addCommand({
		name: 'next-compiler-tab',
		bindKey: 'Alt-PageDown',
		exec: function(editor) {
			var idx = $('#result').tabs('option', 'active');
			var len = $('#result .ui-tabs-nav li').length;
			$('#result').tabs('option', 'active', idx == len - 1 ? 0 : idx + 1);
		},
		readonly: false
	});
	editor.commands.addCommand({
		name: 'prev-compiler-tab',
		bindKey: 'Alt-PageUp',
		exec: function(editor) {
			var idx = $('#result').tabs('option', 'active');
			var len = $('#result .ui-tabs-nav li').length;
			$('#result').tabs('option', 'active', idx > 0 ? idx - 1 : len - 1);
		},
		readonly: false
	});

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
			$('#compiler_types').append('<input type="checkbox" class="ctypes'+(msg[key][1] != 0 ? ' ctypes11' : '')+'" id="' + key + '" name="' + key + '"><label for="' + key + '">[' + key + '] ' + msg[key][0] + '</label>' + (idx % 2 == 1 ? '<br>' : ' '));
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
		if($.cookie('last_compiler_types') !== undefined) {
			$.each($.cookie('last_compiler_types').split('|'), function(idx, key) {
				$('#'+key.replace(/([-+ ])/g, '\\$1')+':not(:checked)').click();
			});
		}
        $('#selectall').click(function(e) {
			$('.ctypes:not(:checked)').click();
		});
        $('#select11all').click(function(e) {
			$('.ctypes11:not(:checked)').click();
		});
        $('#deselectall').click(function(e) {
			$('.ctypes:checked').click();
		});
		$('#input-container').addClass('ui-widget ui-widget-content ui-corner-all');
		$('#source-label').addClass('ui-widget-header ui-corner-all');
		$('#title-row').addClass('ui-widget-header ui-corner-all');
	});
	// Status updater
	var updater = function() {
		var idx = $('#result').tabs('option', 'active');
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
				status[idxmap[idx]].status = 5;
			}
		}
	};
	// Invoke
	$('#form').submit(function() {
		if(editor.getValue().length > 10 * 1024) {
			window.alert('Currently, source size is limited to 10KiB.');
			return false;
		}
		$('.result-tabs').each(function() {
			var tab = $(this).remove();
			$('#' + tab.attr('aria-controls')).remove();
		});
		$('#result').tabs('refresh');
		var types = $.map($('.ctypes:checked'), function(obj, idx) { return obj.name; });
		if(types.length == 0) {
			window.alert('You MUST choose at least one compiler.');
			return false;
		}
		$.cookie('last_compiler_types', types.join('|'), { expires: 30 });
		$.ajax({
			type: 'POST',
			url: 'ccf.cgi',
			traditional: true,
			data: {
				command: 'invoke',
				source: editor.getValue(),
				title: $('#title').val(),
				type: types,
				execute: ($('#compile:checked').length == 0 ? 'true' : 'false'),
			},
			dataType: 'json'
		}).done(function(msg) {
			$('#note').html('Other tabs show results.<br><br>You can see results in a page with <a href="/result/' + msg.id + '">'+location.protocol+'//'+location.host+'/result/'+msg.id+'</a>.<br>NOTE: You may need update manually for this URL until completed.');
			$.each(msg.keys, function(key, id) {
				status[key].id = id;
				idmap[id] = key;
				$('#result').find('.ui-tabs-nav li:eq(' + status[key].idx + ') a').attr('href', 'ccf.cgi?command=show&id=' + id);
			});
			$('#result').tabs('refresh');
		});
		$.each(types, function(idx, obj) {
			// Add new tab
			$('<li class="result-tabs"><a href="ccf.dummy.html">'+obj+'</a></li>').appendTo('#result .ui-tabs-nav');
			status[obj] = { status: 0, idx: $('#result .ui-tabs-nav li').length - 1 };
			idxmap[$('#result .ui-tabs-nav li').length - 1] = obj;
		});
		$('#result').tabs('refresh');
		return false;
	});
	$('#result').tabs(tabopts);
	$('#result').bind('tabsactivate', function(event, ui) {
		setTimeout(updater, 1000);
		return true;
	});
});
