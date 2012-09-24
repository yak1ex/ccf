#
# Makefile for standalone sandbox library extracted from Chromium
#

CHROMIUMDIR=..\..\chromium
OUTDIR=out

CXXFLAGS=/I$(CHROMIUMDIR) /nologo /W3 /WX- /Od /Oy- /D _DEBUG /D _WIN32_WINNT=0x0602 /D WINVER=0x0602 /D WIN32 /D _WINDOWS /D NOMINMAX /D PSAPI_VERSION=1 /D _CRT_RAND_S /D CERT_CHAIN_PARA_HAS_EXTRA_FIELDS /D WIN32_LEAN_AND_MEAN /D _CRT_SECURE_NO_DEPRECATE /D _SCL_SECURE_NO_DEPRECATE /D __STDC_FORMAT_MACROS /D DYNAMIC_ANNOTATIONS_ENABLED=1 /D WTF_USE_DYNAMIC_ANNOTATIONS=1 /D _LIB /D _UNICODE /D UNICODE /EHsc /RTC1 /MDd /GS /fp:precise /Zc:wchar_t /Zc:forScope /Fo"$(OUTDIR)\\" /Fd"$(OUTDIR)" /Gd /TP /analyze- /errorReport:prompt

CFLAGS=/I$(CHROMIUMDIR) /nologo /W3 /WX- /Od /Oy- /D _DEBUG /D _WIN32_WINNT=0x0602 /D WINVER=0x0602 /D WIN32 /D _WINDOWS /D NOMINMAX /D PSAPI_VERSION=1 /D _CRT_RAND_S /D CERT_CHAIN_PARA_HAS_EXTRA_FIELDS /D WIN32_LEAN_AND_MEAN /D _CRT_SECURE_NO_DEPRECATE /D _SCL_SECURE_NO_DEPRECATE /D __STDC_FORMAT_MACROS /D DYNAMIC_ANNOTATIONS_ENABLED=1 /D WTF_USE_DYNAMIC_ANNOTATIONS=1 /D _LIB /D _UNICODE /D UNICODE /EHsc /RTC1 /MDd /GS /fp:precise /Zc:wchar_t /Zc:forScope /Fo"$(OUTDIR)\\" /Fd"$(OUTDIR)" /Gd /TC /analyze- /errorReport:prompt

{$(CHROMIUMDIR)\base}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\debug}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\memory}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\metrics}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\profiler}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\synchronization}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\third_party\dmg_fp}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\third_party\dynamic_annotations}.c{$(OUTDIR)}.obj::
	$(CC) $(CFLAGS) /c $<
{$(CHROMIUMDIR)\base\third_party\icu}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\third_party\nspr}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\threading}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\base\win}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\sandbox\win\src}.cc{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<
{$(CHROMIUMDIR)\sandbox\win\src\sidestep}.cpp{$(OUTDIR)}.obj::
	$(CXX) $(CXXFLAGS) /c $<

OBJS= $(OUTDIR)\at_exit.obj \
      $(OUTDIR)\base_switches.obj \
      $(OUTDIR)\callback_internal.obj \
      $(OUTDIR)\command_line.obj \
      $(OUTDIR)\cpu.obj \
      $(OUTDIR)\alias.obj \
      $(OUTDIR)\debugger.obj \
      $(OUTDIR)\debugger_win.obj \
      $(OUTDIR)\profiler.obj \
      $(OUTDIR)\stack_trace.obj \
      $(OUTDIR)\stack_trace_win.obj \
      $(OUTDIR)\trace_event.obj \
      $(OUTDIR)\trace_event_impl.obj \
      $(OUTDIR)\trace_event_win.obj \
      $(OUTDIR)\file_path.obj \
      $(OUTDIR)\lazy_instance.obj \
      $(OUTDIR)\location.obj \
      $(OUTDIR)\logging.obj \
      $(OUTDIR)\ref_counted.obj \
      $(OUTDIR)\ref_counted_memory.obj \
      $(OUTDIR)\singleton.obj \
      $(OUTDIR)\weak_ptr.obj \
      $(OUTDIR)\message_loop.obj \
      $(OUTDIR)\message_loop_proxy.obj \
      $(OUTDIR)\message_loop_proxy_impl.obj \
      $(OUTDIR)\message_pump.obj \
      $(OUTDIR)\message_pump_default.obj \
      $(OUTDIR)\message_pump_win.obj \
      $(OUTDIR)\bucket_ranges.obj \
      $(OUTDIR)\histogram.obj \
      $(OUTDIR)\histogram_base.obj \
      $(OUTDIR)\statistics_recorder.obj \
      $(OUTDIR)\pending_task.obj \
      $(OUTDIR)\pickle.obj \
      $(OUTDIR)\process_util.obj \
      $(OUTDIR)\process_util_win.obj \
      $(OUTDIR)\alternate_timer.obj \
      $(OUTDIR)\tracked_time.obj \
      $(OUTDIR)\run_loop.obj \
      $(OUTDIR)\stringprintf.obj \
      $(OUTDIR)\string_number_conversions.obj \
      $(OUTDIR)\string_piece.obj \
      $(OUTDIR)\string_split.obj \
      $(OUTDIR)\string_util.obj \
      $(OUTDIR)\lock.obj \
      $(OUTDIR)\lock_impl_win.obj \
      $(OUTDIR)\waitable_event_win.obj \
      $(OUTDIR)\sys_info_win.obj \
      $(OUTDIR)\task_runner.obj \
      $(OUTDIR)\dtoa.obj \
      $(OUTDIR)\g_fmt.obj \
      $(OUTDIR)\dynamic_annotations.obj \
      $(OUTDIR)\icu_utf.obj \
      $(OUTDIR)\prtime.obj \
      $(OUTDIR)\platform_thread_win.obj \
      $(OUTDIR)\post_task_and_reply_impl.obj \
      $(OUTDIR)\thread_checker_impl.obj \
      $(OUTDIR)\thread_collision_warner.obj \
      $(OUTDIR)\thread_local_storage_win.obj \
      $(OUTDIR)\thread_local_win.obj \
      $(OUTDIR)\thread_restrictions.obj \
      $(OUTDIR)\thread_task_runner_handle.obj \
      $(OUTDIR)\time.obj \
      $(OUTDIR)\time_win.obj \
      $(OUTDIR)\tracked_objects.obj \
      $(OUTDIR)\tracking_info.obj \
      $(OUTDIR)\utf_string_conversions.obj \
      $(OUTDIR)\utf_string_conversion_utils.obj \
      $(OUTDIR)\vlog.obj \
      $(OUTDIR)\event_trace_provider.obj \
      $(OUTDIR)\object_watcher.obj \
      $(OUTDIR)\pe_image.obj \
      $(OUTDIR)\scoped_handle.obj \
      $(OUTDIR)\scoped_process_information.obj \
      $(OUTDIR)\windows_version.obj \
      $(OUTDIR)\wrapped_window_proc.obj \
      $(OUTDIR)\acl.obj \
      $(OUTDIR)\broker_services.obj \
      $(OUTDIR)\crosscall_server.obj \
      $(OUTDIR)\dep.obj \
      $(OUTDIR)\eat_resolver.obj \
      $(OUTDIR)\filesystem_dispatcher.obj \
      $(OUTDIR)\filesystem_interception.obj \
      $(OUTDIR)\filesystem_policy.obj \
      $(OUTDIR)\handle_closer.obj \
      $(OUTDIR)\handle_closer_agent.obj \
      $(OUTDIR)\handle_dispatcher.obj \
      $(OUTDIR)\handle_interception.obj \
      $(OUTDIR)\handle_policy.obj \
      $(OUTDIR)\handle_table.obj \
      $(OUTDIR)\interception.obj \
      $(OUTDIR)\interception_agent.obj \
      $(OUTDIR)\job.obj \
      $(OUTDIR)\named_pipe_dispatcher.obj \
      $(OUTDIR)\named_pipe_interception.obj \
      $(OUTDIR)\named_pipe_policy.obj \
      $(OUTDIR)\policy_broker.obj \
      $(OUTDIR)\policy_engine_opcodes.obj \
      $(OUTDIR)\policy_engine_processor.obj \
      $(OUTDIR)\policy_low_level.obj \
      $(OUTDIR)\policy_target.obj \
      $(OUTDIR)\process_thread_dispatcher.obj \
      $(OUTDIR)\process_thread_interception.obj \
      $(OUTDIR)\process_thread_policy.obj \
      $(OUTDIR)\registry_dispatcher.obj \
      $(OUTDIR)\registry_interception.obj \
      $(OUTDIR)\registry_policy.obj \
      $(OUTDIR)\resolver.obj \
      $(OUTDIR)\resolver_32.obj \
      $(OUTDIR)\restricted_token.obj \
      $(OUTDIR)\restricted_token_utils.obj \
      $(OUTDIR)\sandbox.obj \
      $(OUTDIR)\sandbox_nt_util.obj \
      $(OUTDIR)\sandbox_policy_base.obj \
      $(OUTDIR)\sandbox_utils.obj \
      $(OUTDIR)\service_resolver.obj \
      $(OUTDIR)\service_resolver_32.obj \
      $(OUTDIR)\sharedmem_ipc_client.obj \
      $(OUTDIR)\sharedmem_ipc_server.obj \
      $(OUTDIR)\shared_handles.obj \
      $(OUTDIR)\sid.obj \
      $(OUTDIR)\ia32_modrm_map.obj \
      $(OUTDIR)\ia32_opcode_map.obj \
      $(OUTDIR)\mini_disassembler.obj \
      $(OUTDIR)\preamble_patcher_with_stub.obj \
      $(OUTDIR)\sidestep_resolver.obj \
      $(OUTDIR)\sync_dispatcher.obj \
      $(OUTDIR)\sync_interception.obj \
      $(OUTDIR)\sync_policy.obj \
      $(OUTDIR)\target_interceptions.obj \
      $(OUTDIR)\target_process.obj \
      $(OUTDIR)\target_services.obj \
      $(OUTDIR)\win2k_threadpool.obj \
      $(OUTDIR)\window.obj \
      $(OUTDIR)\win_utils.obj \
      $(OUTDIR)\Wow64.obj

all: $(OUTDIR) $(OUTDIR)\sandbox-win-standalone.lib

$(OUTDIR)\sandbox-win-standalone.lib: $(OBJS)
	Lib.exe /OUT:$@ /NOLOGO $**

$(OUTDIR):
	mkdir $(OUTDIR)

clean:
	del Debug\*.*
