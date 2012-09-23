#include <windows.h>
#include <io.h>
#include <fcntl.h>

#include <iostream>
#include <fstream>
#include <cstdio>

#include <process.h>

#include "sandbox/win/src/sandbox.h"
#include "sandbox/win/src/sandbox_factory.h"

extern "C" int main_(int argc, char** argv);

class StdHandleSaver
{
	std::streambuf *cin, *cout, *cerr, *clog;
	struct CStreamHandler
	{
		CStreamHandler(const char* in, const char* out)
		{
			_close(0); _close(1); _close(2);

			freopen(in, "r", stdin);
			freopen(out, "w", stdout);
			freopen(out, "w", stderr);
			setbuf(stderr, NULL);
		}
		~CStreamHandler()
		{
			fclose(stdin);
			fclose(stdout);
			fclose(stderr);
		}
	} csh;
	std::ofstream ofs;
	std::ifstream ifs;
public:
	StdHandleSaver(const char* in, const char* out) :
		cin(std::cin.rdbuf()), cout(std::cout.rdbuf()), cerr(std::cerr.rdbuf()), clog(std::clog.rdbuf()),
		csh(in, out),
//	NOTE: Using undocumented constructor accepting FILE*
//	      Only onstructor accepts FILE* and swap is spcified since C++11, so we need to use constructor
		ifs(stdin), ofs(stdout)
	{
		std::cin.rdbuf(ifs.rdbuf());
		std::cout.rdbuf(ofs.rdbuf());
		std::cerr.rdbuf(ofs.rdbuf());
		std::clog.rdbuf(ofs.rdbuf());
	}
	~StdHandleSaver()
	{
		std::cin.rdbuf(cin);
		std::cout.rdbuf(cout);
		std::cerr.rdbuf(cerr);
		std::clog.rdbuf(clog);
	}
};

int main(int argc, char** argv)
{
	if(!getenv("SANDBOX_IN") || !getenv("SANDBOX_OUT") || !getenv("SANDBOX_MEMLIMIT") || !getenv("SANDBOX_CPULIMIT") || !getenv("SANDBOX_RTLIMIT")) return 250;

	sandbox::BrokerServices* broker_service = sandbox::SandboxFactory::GetBrokerServices();
	sandbox::ResultCode result;

	int ret = 0;

	if(broker_service != NULL) {

		if ((result = broker_service->Init())) {
			std::cerr << "Initialization of broker service failed." << std::endl;
			return 1;
		}

		sandbox::TargetPolicy* policy = broker_service->CreatePolicy();
		SIZE_T memlimit = std::atoi(getenv("SANDBOX_MEMLIMIT"));
		if(memlimit)
			policy->SetJobPerProcessMemoryLimit(memlimit);
		LONGLONG cpulimit = _strtoi64(getenv("SANDBOX_CPULIMIT"), 0, 10);
		if(cpulimit)
			policy->SetJobPerProcessUserTimeLimit(cpulimit);
#ifdef SANDBOX_COMPILER
		policy->SetJobLevel(sandbox::JOB_INTERACTIVE, 0);
		policy->SetTokenLevel(sandbox::USER_RESTRICTED_SAME_ACCESS, sandbox::USER_INTERACTIVE);
#else
		policy->SetJobLevel(sandbox::JOB_LOCKDOWN, 0);
		policy->SetTokenLevel(sandbox::USER_RESTRICTED_SAME_ACCESS, sandbox::USER_LOCKDOWN);
		policy->SetAlternateDesktop(true);
		policy->SetDelayedIntegrityLevel(sandbox::INTEGRITY_LEVEL_LOW);
#endif
		PROCESS_INFORMATION target_;
		WCHAR self[32768];
		GetModuleFileNameW(NULL, self, sizeof(self)/sizeof(self[0]));
		sandbox::ResultCode result = broker_service->SpawnTarget(self, GetCommandLineW(), policy, &target_);
		policy->Release();
		policy = NULL;

		if(result != sandbox::SBOX_ALL_OK) {
			std::cout << "SpawnTarget failed." << std::endl;
			return -1;
	    }

		::ResumeThread(target_.hThread);

		::CloseHandle(target_.hThread);
		int rtlimit = std::atoi(getenv("SANDBOX_RTLIMIT"));
		if(WaitForSingleObject(target_.hProcess, rtlimit ? rtlimit * 1000 : INFINITE) == WAIT_TIMEOUT) {
			TerminateProcess(target_.hProcess, 3);
			WaitForSingleObject(target_.hProcess, INFINITE);
			std::ofstream ofs(getenv("SANDBOX_OUT"), std::ios::out | std::ios::app);
			ofs << "CCF: Time(real) limit exceeded." << std::endl;
		}
		DWORD dwRet;
		if(GetExitCodeProcess(target_.hProcess, &dwRet)) ret = dwRet;
		::CloseHandle(target_.hProcess);

		broker_service->WaitForAllTargets();

		if(broker_service->IsMemoryLimitTargets()) {
			std::ofstream ofs(getenv("SANDBOX_OUT"), std::ios::out | std::ios::app);
			ofs << "CCF: Memory limit exceeded." << std::endl;
		}
		if(broker_service->IsTimeLimitTargets()) {
			std::ofstream ofs(getenv("SANDBOX_OUT"), std::ios::out | std::ios::app);
			ofs << "CCF: Time limit exceeded." << std::endl;
		}

	} else {

#ifndef SANDBOX_COMPILER
		// SetStdHandle() does not work as expected
		// Before locked-down, we can access arbitrary files.
		StdHandleSaver shs(getenv("SANDBOX_IN"), getenv("SANDBOX_OUT"));
#endif

		sandbox::TargetServices* target_service = sandbox::SandboxFactory::GetTargetServices();
		if (NULL == target_service) {
			std::cerr << "Initialization of target service failed." << std::endl;
			return -1;
		}

		if (sandbox::SBOX_ALL_OK != (result = target_service->Init())) {
			return -2;
		}

		target_service->LowerToken();

		Sleep(1);

		ret = main_(argc, argv);

	}

	return ret;
}

#ifdef SANDBOX_COMPILER
extern "C" int main_(int argc, char** argv)
{
	const char* args[3];
	std::string actualarg;
	args[0] = "cmd.exe";
	args[1] = "/c";
	for(int i = 1; i < argc; ++i) {
		actualarg += argv[i];
		actualarg += ' ';
	}
	actualarg += ">";
	actualarg += getenv("SANDBOX_OUT");
	actualarg += " 2>&1";
	args[2] = actualarg.c_str();
	args[3] = 0;
	_execvp(args[0], args); // Basically, no return
	return 250;
}
#endif
