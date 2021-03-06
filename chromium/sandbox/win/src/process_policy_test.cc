// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <memory>
#include <string>

#include "base/string16.h"
#include "base/sys_string_conversions.h"
#include "base/win/scoped_handle.h"
#include "base/win/scoped_process_information.h"
#include "base/win/windows_version.h"
#include "sandbox/win/src/sandbox.h"
#include "sandbox/win/src/sandbox_policy.h"
#include "sandbox/win/src/sandbox_factory.h"
#include "sandbox/win/tests/common/controller.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace {

// While the shell API provides better calls than this home brew function
// we use GetSystemWindowsDirectoryW which does not query the registry so
// it is safe to use after revert.
string16 MakeFullPathToSystem32(const wchar_t* name) {
  wchar_t windows_path[MAX_PATH] = {0};
  ::GetSystemWindowsDirectoryW(windows_path, MAX_PATH);
  string16 full_path(windows_path);
  if (full_path.empty()) {
    return full_path;
  }
  full_path += L"\\system32\\";
  full_path += name;
  return full_path;
}

// Creates a process with the |exe| and |command| parameter using the
// unicode and ascii version of the api.
sandbox::SboxTestResult CreateProcessHelper(const string16& exe,
                                            const string16& command) {
  base::win::ScopedProcessInformation pi;
  STARTUPINFOW si = {sizeof(si)};

  const wchar_t *exe_name = NULL;
  if (!exe.empty())
    exe_name = exe.c_str();

  const wchar_t *cmd_line = NULL;
  if (!command.empty())
    cmd_line = command.c_str();

  // Create the process with the unicode version of the API.
  sandbox::SboxTestResult ret1 = sandbox::SBOX_TEST_FAILED;
  if (!::CreateProcessW(exe_name, const_cast<wchar_t*>(cmd_line), NULL, NULL,
                        FALSE, 0, NULL, NULL, &si, pi.Receive())) {
    DWORD last_error = GetLastError();
    if ((ERROR_NOT_ENOUGH_QUOTA == last_error) ||
        (ERROR_ACCESS_DENIED == last_error) ||
        (ERROR_FILE_NOT_FOUND == last_error)) {
      ret1 = sandbox::SBOX_TEST_DENIED;
    } else {
      ret1 = sandbox::SBOX_TEST_FAILED;
    }
  } else {
    ret1 = sandbox::SBOX_TEST_SUCCEEDED;
  }

  pi.Close();

  // Do the same with the ansi version of the api
  STARTUPINFOA sia = {sizeof(sia)};
  sandbox::SboxTestResult ret2 = sandbox::SBOX_TEST_FAILED;

  std::string narrow_cmd_line;
  if (cmd_line)
    narrow_cmd_line = base::SysWideToMultiByte(cmd_line, CP_UTF8);
  if (!::CreateProcessA(
        exe_name ? base::SysWideToMultiByte(exe_name, CP_UTF8).c_str() : NULL,
        cmd_line ? const_cast<char*>(narrow_cmd_line.c_str()) : NULL,
        NULL, NULL, FALSE, 0, NULL, NULL, &sia, pi.Receive())) {
    DWORD last_error = GetLastError();
    if ((ERROR_NOT_ENOUGH_QUOTA == last_error) ||
        (ERROR_ACCESS_DENIED == last_error) ||
        (ERROR_FILE_NOT_FOUND == last_error)) {
      ret2 = sandbox::SBOX_TEST_DENIED;
    } else {
      ret2 = sandbox::SBOX_TEST_FAILED;
    }
  } else {
    ret2 = sandbox::SBOX_TEST_SUCCEEDED;
  }

  if (ret1 == ret2)
    return ret1;

  return sandbox::SBOX_TEST_FAILED;
}

}  // namespace

namespace sandbox {

SBOX_TESTS_COMMAND int Process_RunApp1(int argc, wchar_t **argv) {
  if (argc != 1) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  if ((NULL == argv) || (NULL == argv[0])) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  string16 path = MakeFullPathToSystem32(argv[0]);

  // TEST 1: Try with the path in the app_name.
  return CreateProcessHelper(path, string16());
}

SBOX_TESTS_COMMAND int Process_RunApp2(int argc, wchar_t **argv) {
  if (argc != 1) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  if ((NULL == argv) || (NULL == argv[0])) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  string16 path = MakeFullPathToSystem32(argv[0]);

  // TEST 2: Try with the path in the cmd_line.
  string16 cmd_line = L"\"";
  cmd_line += path;
  cmd_line += L"\"";
  return CreateProcessHelper(string16(), cmd_line);
}

SBOX_TESTS_COMMAND int Process_RunApp3(int argc, wchar_t **argv) {
  if (argc != 1) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  if ((NULL == argv) || (NULL == argv[0])) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }

  // TEST 3: Try file name in the cmd_line.
  return CreateProcessHelper(string16(), argv[0]);
}

SBOX_TESTS_COMMAND int Process_RunApp4(int argc, wchar_t **argv) {
  if (argc != 1) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  if ((NULL == argv) || (NULL == argv[0])) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }

  // TEST 4: Try file name in the app_name and current directory sets correctly.
  string16 system32 = MakeFullPathToSystem32(L"");
  wchar_t current_directory[MAX_PATH + 1];
  int result4;
  bool test_succeeded = false;
  DWORD ret = ::GetCurrentDirectory(MAX_PATH, current_directory);
  if (!ret)
    return SBOX_TEST_FIRST_ERROR;

  if (ret < MAX_PATH) {
    current_directory[ret] = L'\\';
    current_directory[ret+1] = L'\0';
    if (::SetCurrentDirectory(system32.c_str())) {
      result4 = CreateProcessHelper(argv[0], string16());
      if (::SetCurrentDirectory(current_directory)) {
        test_succeeded = true;
      }
    } else {
      return SBOX_TEST_SECOND_ERROR;
    }
  }
  if (!test_succeeded)
    result4 = SBOX_TEST_FAILED;

  return result4;
}

SBOX_TESTS_COMMAND int Process_RunApp5(int argc, wchar_t **argv) {
  if (argc != 1) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  if ((NULL == argv) || (NULL == argv[0])) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  string16 path = MakeFullPathToSystem32(argv[0]);

  // TEST 5: Try with the path in the cmd_line and arguments.
  string16 cmd_line = L"\"";
  cmd_line += path;
  cmd_line += L"\" /I";
  return CreateProcessHelper(string16(), cmd_line);
}

SBOX_TESTS_COMMAND int Process_RunApp6(int argc, wchar_t **argv) {
  if (argc != 1) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }
  if ((NULL == argv) || (NULL == argv[0])) {
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;
  }

  // TEST 6: Try with the file_name in the cmd_line and arguments.
  string16 cmd_line = argv[0];
  cmd_line += L" /I";
  return CreateProcessHelper(string16(), cmd_line);
}

// Creates a process and checks if it's possible to get a handle to it's token.
SBOX_TESTS_COMMAND int Process_GetChildProcessToken(int argc, wchar_t **argv) {
  if (argc != 1)
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;

  if ((NULL == argv) || (NULL == argv[0]))
    return SBOX_TEST_FAILED_TO_EXECUTE_COMMAND;

  string16 path = MakeFullPathToSystem32(argv[0]);

  base::win::ScopedProcessInformation pi;
  STARTUPINFOW si = {sizeof(si)};

  if (!::CreateProcessW(path.c_str(), NULL, NULL, NULL, FALSE, CREATE_SUSPENDED,
                        NULL, NULL, &si, pi.Receive())) {
      return SBOX_TEST_FAILED;
  }

  HANDLE token = NULL;
  BOOL result =
      ::OpenProcessToken(pi.process_handle(), TOKEN_IMPERSONATE, &token);
  DWORD error = ::GetLastError();

  base::win::ScopedHandle token_handle(token);

  if (!::TerminateProcess(pi.process_handle(), 0))
    return SBOX_TEST_FAILED;

  if (result && token)
    return SBOX_TEST_SUCCEEDED;

  if (ERROR_ACCESS_DENIED == error)
    return SBOX_TEST_DENIED;

  return SBOX_TEST_FAILED;
}


SBOX_TESTS_COMMAND int Process_OpenToken(int argc, wchar_t **argv) {
  HANDLE token;
  if (!::OpenProcessToken(::GetCurrentProcess(), TOKEN_ALL_ACCESS, &token)) {
    if (ERROR_ACCESS_DENIED == ::GetLastError()) {
      return SBOX_TEST_DENIED;
    }
  } else {
    ::CloseHandle(token);
    return SBOX_TEST_SUCCEEDED;
  }

  return SBOX_TEST_FAILED;
}

TEST(ProcessPolicyTest, TestAllAccess) {
  // Check if the "all access" rule fails to be added when the token is too
  // powerful.
  TestRunner runner;

  // Check the failing case.
  runner.GetPolicy()->SetTokenLevel(USER_INTERACTIVE, USER_LOCKDOWN);
  EXPECT_EQ(SBOX_ERROR_UNSUPPORTED,
            runner.GetPolicy()->AddRule(TargetPolicy::SUBSYS_PROCESS,
                                        TargetPolicy::PROCESS_ALL_EXEC,
                                        L"this is not important"));

  // Check the working case.
  runner.GetPolicy()->SetTokenLevel(USER_INTERACTIVE, USER_INTERACTIVE);

  EXPECT_EQ(SBOX_ALL_OK,
            runner.GetPolicy()->AddRule(TargetPolicy::SUBSYS_PROCESS,
                                        TargetPolicy::PROCESS_ALL_EXEC,
                                        L"this is not important"));
}

TEST(ProcessPolicyTest, CreateProcessAW) {
  TestRunner runner;
  string16 exe_path = MakeFullPathToSystem32(L"findstr.exe");
  string16 system32 = MakeFullPathToSystem32(L"");
  ASSERT_TRUE(!exe_path.empty());
  EXPECT_TRUE(runner.AddRule(TargetPolicy::SUBSYS_PROCESS,
                             TargetPolicy::PROCESS_MIN_EXEC,
                             exe_path.c_str()));

  // Need to add directory rules for the directories that we use in
  // SetCurrentDirectory.
  EXPECT_TRUE(runner.AddFsRule(TargetPolicy::FILES_ALLOW_DIR_ANY,
                               system32.c_str()));

  wchar_t current_directory[MAX_PATH];
  DWORD ret = ::GetCurrentDirectory(MAX_PATH, current_directory);
  ASSERT_TRUE(0 != ret && ret < MAX_PATH);

  wcscat_s(current_directory, MAX_PATH, L"\\");
  EXPECT_TRUE(runner.AddFsRule(TargetPolicy::FILES_ALLOW_DIR_ANY,
                               current_directory));

  EXPECT_EQ(SBOX_TEST_DENIED, runner.RunTest(L"Process_RunApp1 calc.exe"));
  EXPECT_EQ(SBOX_TEST_DENIED, runner.RunTest(L"Process_RunApp2 calc.exe"));
  EXPECT_EQ(SBOX_TEST_DENIED, runner.RunTest(L"Process_RunApp3 calc.exe"));
  EXPECT_EQ(SBOX_TEST_DENIED, runner.RunTest(L"Process_RunApp5 calc.exe"));
  EXPECT_EQ(SBOX_TEST_DENIED, runner.RunTest(L"Process_RunApp6 calc.exe"));

  EXPECT_EQ(SBOX_TEST_SUCCEEDED,
            runner.RunTest(L"Process_RunApp1 findstr.exe"));
  EXPECT_EQ(SBOX_TEST_SUCCEEDED,
            runner.RunTest(L"Process_RunApp2 findstr.exe"));
  EXPECT_EQ(SBOX_TEST_SUCCEEDED,
            runner.RunTest(L"Process_RunApp3 findstr.exe"));
  EXPECT_EQ(SBOX_TEST_SUCCEEDED,
            runner.RunTest(L"Process_RunApp5 findstr.exe"));
  EXPECT_EQ(SBOX_TEST_SUCCEEDED,
            runner.RunTest(L"Process_RunApp6 findstr.exe"));

  if (base::win::OSInfo::GetInstance()->version() >= base::win::VERSION_VISTA) {
    // WinXP results are not reliable.
    EXPECT_EQ(SBOX_TEST_SECOND_ERROR,
        runner.RunTest(L"Process_RunApp4 calc.exe"));
    EXPECT_EQ(SBOX_TEST_SECOND_ERROR,
        runner.RunTest(L"Process_RunApp4 findstr.exe"));
  }
}

TEST(ProcessPolicyTest, OpenToken) {
  TestRunner runner;
  EXPECT_EQ(SBOX_TEST_SUCCEEDED, runner.RunTest(L"Process_OpenToken"));
}

TEST(ProcessPolicyTest, TestGetProcessTokenMinAccess) {
  TestRunner runner;
  string16 exe_path = MakeFullPathToSystem32(L"findstr.exe");
  ASSERT_TRUE(!exe_path.empty());
  EXPECT_TRUE(runner.AddRule(TargetPolicy::SUBSYS_PROCESS,
                             TargetPolicy::PROCESS_MIN_EXEC,
                             exe_path.c_str()));

  EXPECT_EQ(SBOX_TEST_DENIED,
            runner.RunTest(L"Process_GetChildProcessToken findstr.exe"));
}

TEST(ProcessPolicyTest, TestGetProcessTokenMaxAccess) {
  TestRunner runner(JOB_UNPROTECTED, USER_INTERACTIVE, USER_INTERACTIVE);
  string16 exe_path = MakeFullPathToSystem32(L"findstr.exe");
  ASSERT_TRUE(!exe_path.empty());
  EXPECT_TRUE(runner.AddRule(TargetPolicy::SUBSYS_PROCESS,
                             TargetPolicy::PROCESS_ALL_EXEC,
                             exe_path.c_str()));

  EXPECT_EQ(SBOX_TEST_SUCCEEDED,
            runner.RunTest(L"Process_GetChildProcessToken findstr.exe"));
}

}  // namespace sandbox
