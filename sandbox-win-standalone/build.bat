rmdir /s /q Debug
mkdir Debug
CL.exe /c /I..\chromium /ZI /nologo /W3 /WX- /Od /Oy- /D _DEBUG /D _WIN32_WINNT=0x0602 /D WINVER=0x0602 /D WIN32 /D _WINDOWS /D NOMINMAX /D PSAPI_VERSION=1 /D _CRT_RAND_S /D CERT_CHAIN_PARA_HAS_EXTRA_FIELDS /D WIN32_LEAN_AND_MEAN /D _CRT_SECURE_NO_DEPRECATE /D _SCL_SECURE_NO_DEPRECATE /D __STDC_FORMAT_MACROS /D DYNAMIC_ANNOTATIONS_ENABLED=1 /D WTF_USE_DYNAMIC_ANNOTATIONS=1 /D _LIB /D _UNICODE /D UNICODE /Gm /EHsc /RTC1 /MDd /GS /fp:precise /Zc:wchar_t /Zc:forScope /Fo"Debug\\" /Fd"Debug\vc100.pdb" /Gd /TP /analyze- /errorReport:prompt ..\chromium\base\at_exit.cc ..\chromium\base\base_switches.cc ..\chromium\base\callback_internal.cc ..\chromium\base\command_line.cc ..\chromium\base\cpu.cc ..\chromium\base\debug\alias.cc ..\chromium\base\debug\debugger.cc ..\chromium\base\debug\debugger_win.cc ..\chromium\base\debug\profiler.cc ..\chromium\base\debug\stack_trace.cc ..\chromium\base\debug\stack_trace_win.cc ..\chromium\base\debug\trace_event.cc ..\chromium\base\debug\trace_event_impl.cc ..\chromium\base\debug\trace_event_win.cc ..\chromium\base\file_path.cc ..\chromium\base\lazy_instance.cc ..\chromium\base\location.cc ..\chromium\base\logging.cc ..\chromium\base\memory\ref_counted.cc ..\chromium\base\memory\ref_counted_memory.cc ..\chromium\base\memory\singleton.cc ..\chromium\base\memory\weak_ptr.cc ..\chromium\base\message_loop.cc ..\chromium\base\message_loop_proxy.cc ..\chromium\base\message_loop_proxy_impl.cc ..\chromium\base\message_pump.cc ..\chromium\base\message_pump_default.cc ..\chromium\base\message_pump_win.cc ..\chromium\base\metrics\bucket_ranges.cc ..\chromium\base\metrics\histogram.cc ..\chromium\base\metrics\histogram_base.cc ..\chromium\base\metrics\statistics_recorder.cc ..\chromium\base\pending_task.cc ..\chromium\base\pickle.cc ..\chromium\base\process_util.cc ..\chromium\base\process_util_win.cc ..\chromium\base\profiler\alternate_timer.cc ..\chromium\base\profiler\tracked_time.cc ..\chromium\base\run_loop.cc ..\chromium\base\stringprintf.cc ..\chromium\base\string_number_conversions.cc ..\chromium\base\string_piece.cc ..\chromium\base\string_split.cc ..\chromium\base\string_util.cc ..\chromium\base\synchronization\lock.cc ..\chromium\base\synchronization\lock_impl_win.cc ..\chromium\base\synchronization\waitable_event_win.cc ..\chromium\base\sys_info_win.cc ..\chromium\base\task_runner.cc ..\chromium\base\third_party\dmg_fp\dtoa.cc ..\chromium\base\third_party\dmg_fp\g_fmt.cc ..\chromium\base\third_party\icu\icu_utf.cc ..\chromium\base\third_party\nspr\prtime.cc ..\chromium\base\threading\platform_thread_win.cc ..\chromium\base\threading\post_task_and_reply_impl.cc ..\chromium\base\threading\thread_checker_impl.cc ..\chromium\base\threading\thread_collision_warner.cc ..\chromium\base\threading\thread_local_storage_win.cc ..\chromium\base\threading\thread_local_win.cc ..\chromium\base\threading\thread_restrictions.cc ..\chromium\base\thread_task_runner_handle.cc ..\chromium\base\time.cc ..\chromium\base\time_win.cc ..\chromium\base\tracked_objects.cc ..\chromium\base\tracking_info.cc ..\chromium\base\utf_string_conversions.cc ..\chromium\base\utf_string_conversion_utils.cc ..\chromium\base\vlog.cc ..\chromium\base\win\event_trace_provider.cc ..\chromium\base\win\object_watcher.cc ..\chromium\base\win\pe_image.cc ..\chromium\base\win\scoped_handle.cc ..\chromium\base\win\scoped_process_information.cc ..\chromium\base\win\windows_version.cc ..\chromium\base\win\wrapped_window_proc.cc ..\chromium\sandbox\win\src\acl.cc ..\chromium\sandbox\win\src\broker_services.cc ..\chromium\sandbox\win\src\crosscall_server.cc ..\chromium\sandbox\win\src\dep.cc ..\chromium\sandbox\win\src\eat_resolver.cc ..\chromium\sandbox\win\src\filesystem_dispatcher.cc ..\chromium\sandbox\win\src\filesystem_interception.cc ..\chromium\sandbox\win\src\filesystem_policy.cc ..\chromium\sandbox\win\src\handle_closer.cc ..\chromium\sandbox\win\src\handle_closer_agent.cc ..\chromium\sandbox\win\src\handle_dispatcher.cc ..\chromium\sandbox\win\src\handle_interception.cc ..\chromium\sandbox\win\src\handle_policy.cc ..\chromium\sandbox\win\src\handle_table.cc ..\chromium\sandbox\win\src\interception.cc ..\chromium\sandbox\win\src\interception_agent.cc ..\chromium\sandbox\win\src\job.cc ..\chromium\sandbox\win\src\named_pipe_dispatcher.cc ..\chromium\sandbox\win\src\named_pipe_interception.cc ..\chromium\sandbox\win\src\named_pipe_policy.cc ..\chromium\sandbox\win\src\policy_broker.cc ..\chromium\sandbox\win\src\policy_engine_opcodes.cc ..\chromium\sandbox\win\src\policy_engine_processor.cc ..\chromium\sandbox\win\src\policy_low_level.cc ..\chromium\sandbox\win\src\policy_target.cc ..\chromium\sandbox\win\src\process_thread_dispatcher.cc ..\chromium\sandbox\win\src\process_thread_interception.cc ..\chromium\sandbox\win\src\process_thread_policy.cc ..\chromium\sandbox\win\src\registry_dispatcher.cc ..\chromium\sandbox\win\src\registry_interception.cc ..\chromium\sandbox\win\src\registry_policy.cc ..\chromium\sandbox\win\src\resolver.cc ..\chromium\sandbox\win\src\resolver_32.cc ..\chromium\sandbox\win\src\restricted_token.cc ..\chromium\sandbox\win\src\restricted_token_utils.cc ..\chromium\sandbox\win\src\sandbox.cc ..\chromium\sandbox\win\src\sandbox_nt_util.cc ..\chromium\sandbox\win\src\sandbox_policy_base.cc ..\chromium\sandbox\win\src\sandbox_utils.cc ..\chromium\sandbox\win\src\service_resolver.cc ..\chromium\sandbox\win\src\service_resolver_32.cc ..\chromium\sandbox\win\src\sharedmem_ipc_client.cc ..\chromium\sandbox\win\src\sharedmem_ipc_server.cc ..\chromium\sandbox\win\src\shared_handles.cc ..\chromium\sandbox\win\src\sid.cc ..\chromium\sandbox\win\src\sidestep\ia32_modrm_map.cpp ..\chromium\sandbox\win\src\sidestep\ia32_opcode_map.cpp ..\chromium\sandbox\win\src\sidestep\mini_disassembler.cpp ..\chromium\sandbox\win\src\sidestep\preamble_patcher_with_stub.cpp ..\chromium\sandbox\win\src\sidestep_resolver.cc ..\chromium\sandbox\win\src\sync_dispatcher.cc ..\chromium\sandbox\win\src\sync_interception.cc ..\chromium\sandbox\win\src\sync_policy.cc ..\chromium\sandbox\win\src\target_interceptions.cc ..\chromium\sandbox\win\src\target_process.cc ..\chromium\sandbox\win\src\target_services.cc ..\chromium\sandbox\win\src\win2k_threadpool.cc ..\chromium\sandbox\win\src\window.cc ..\chromium\sandbox\win\src\win_utils.cc ..\chromium\sandbox\win\src\Wow64.cc

Lib.exe /OUT:"Debug\sandbox-win-standalone.lib" /NOLOGO Debug\at_exit.obj ^
         Debug\base_switches.obj ^
         Debug\callback_internal.obj ^
         Debug\command_line.obj ^
         Debug\cpu.obj ^
         Debug\alias.obj ^
         Debug\debugger.obj ^
         Debug\debugger_win.obj ^
         Debug\profiler.obj ^
         Debug\stack_trace.obj ^
         Debug\stack_trace_win.obj ^
         Debug\trace_event.obj ^
         Debug\trace_event_impl.obj ^
         Debug\trace_event_win.obj ^
         Debug\file_path.obj ^
         Debug\lazy_instance.obj ^
         Debug\location.obj ^
         Debug\logging.obj ^
         Debug\ref_counted.obj ^
         Debug\ref_counted_memory.obj ^
         Debug\singleton.obj ^
         Debug\weak_ptr.obj ^
         Debug\message_loop.obj ^
         Debug\message_loop_proxy.obj ^
         Debug\message_loop_proxy_impl.obj ^
         Debug\message_pump.obj ^
         Debug\message_pump_default.obj ^
         Debug\message_pump_win.obj ^
         Debug\bucket_ranges.obj ^
         Debug\histogram.obj ^
         Debug\histogram_base.obj ^
         Debug\statistics_recorder.obj ^
         Debug\pending_task.obj ^
         Debug\pickle.obj ^
         Debug\process_util.obj ^
         Debug\process_util_win.obj ^
         Debug\alternate_timer.obj ^
         Debug\tracked_time.obj ^
         Debug\run_loop.obj ^
         Debug\stringprintf.obj ^
         Debug\string_number_conversions.obj ^
         Debug\string_piece.obj ^
         Debug\string_split.obj ^
         Debug\string_util.obj ^
         Debug\lock.obj ^
         Debug\lock_impl_win.obj ^
         Debug\waitable_event_win.obj ^
         Debug\sys_info_win.obj ^
         Debug\task_runner.obj ^
         Debug\dtoa.obj ^
         Debug\g_fmt.obj ^
         Debug\dynamic_annotations.obj ^
         Debug\icu_utf.obj ^
         Debug\prtime.obj ^
         Debug\platform_thread_win.obj ^
         Debug\post_task_and_reply_impl.obj ^
         Debug\thread_checker_impl.obj ^
         Debug\thread_collision_warner.obj ^
         Debug\thread_local_storage_win.obj ^
         Debug\thread_local_win.obj ^
         Debug\thread_restrictions.obj ^
         Debug\thread_task_runner_handle.obj ^
         Debug\time.obj ^
         Debug\time_win.obj ^
         Debug\tracked_objects.obj ^
         Debug\tracking_info.obj ^
         Debug\utf_string_conversions.obj ^
         Debug\utf_string_conversion_utils.obj ^
         Debug\vlog.obj ^
         Debug\event_trace_provider.obj ^
         Debug\object_watcher.obj ^
         Debug\pe_image.obj ^
         Debug\scoped_handle.obj ^
         Debug\scoped_process_information.obj ^
         Debug\windows_version.obj ^
         Debug\wrapped_window_proc.obj ^
         Debug\acl.obj ^
         Debug\broker_services.obj ^
         Debug\crosscall_server.obj ^
         Debug\dep.obj ^
         Debug\eat_resolver.obj ^
         Debug\filesystem_dispatcher.obj ^
         Debug\filesystem_interception.obj ^
         Debug\filesystem_policy.obj ^
         Debug\handle_closer.obj ^
         Debug\handle_closer_agent.obj ^
         Debug\handle_dispatcher.obj ^
         Debug\handle_interception.obj ^
         Debug\handle_policy.obj ^
         Debug\handle_table.obj ^
         Debug\interception.obj ^
         Debug\interception_agent.obj ^
         Debug\job.obj ^
         Debug\named_pipe_dispatcher.obj ^
         Debug\named_pipe_interception.obj ^
         Debug\named_pipe_policy.obj ^
         Debug\policy_broker.obj ^
         Debug\policy_engine_opcodes.obj ^
         Debug\policy_engine_processor.obj ^
         Debug\policy_low_level.obj ^
         Debug\policy_target.obj ^
         Debug\process_thread_dispatcher.obj ^
         Debug\process_thread_interception.obj ^
         Debug\process_thread_policy.obj ^
         Debug\registry_dispatcher.obj ^
         Debug\registry_interception.obj ^
         Debug\registry_policy.obj ^
         Debug\resolver.obj ^
         Debug\resolver_32.obj ^
         Debug\restricted_token.obj ^
         Debug\restricted_token_utils.obj ^
         Debug\sandbox.obj ^
         Debug\sandbox_nt_util.obj ^
         Debug\sandbox_policy_base.obj ^
         Debug\sandbox_utils.obj ^
         Debug\service_resolver.obj ^
         Debug\service_resolver_32.obj ^
         Debug\sharedmem_ipc_client.obj ^
         Debug\sharedmem_ipc_server.obj ^
         Debug\shared_handles.obj ^
         Debug\sid.obj ^
         Debug\ia32_modrm_map.obj ^
         Debug\ia32_opcode_map.obj ^
         Debug\mini_disassembler.obj ^
         Debug\preamble_patcher_with_stub.obj ^
         Debug\sidestep_resolver.obj ^
         Debug\sync_dispatcher.obj ^
         Debug\sync_interception.obj ^
         Debug\sync_policy.obj ^
         Debug\target_interceptions.obj ^
         Debug\target_process.obj ^
         Debug\target_services.obj ^
         Debug\win2k_threadpool.obj ^
         Debug\window.obj ^
         Debug\win_utils.obj ^
         Debug\Wow64.obj
