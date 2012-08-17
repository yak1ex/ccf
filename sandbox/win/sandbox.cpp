#include <windows.h>
#include <io.h>
#include <fcntl.h>

#include <iostream>
#include <fstream>
#include <cstdio>

#include "sandbox/win/src/sandbox.h"
#include "sandbox/win/src/sandbox_factory.h"

extern "C" int main_(int argc, char** argv);

class StdHandleSaver
{
	std::streambuf *cin, *cout, *cerr, *clog;
	std::ofstream ofs;
	std::ifstream ifs;
public:
	StdHandleSaver(const char* in, const char* out) :
		cin(std::cin.rdbuf()), cout(std::cout.rdbuf()), cerr(std::cerr.rdbuf()), clog(std::clog.rdbuf())
	{
		_close(0); _close(1); _close(2);

		freopen(in, "r", stdin);
		freopen(out, "w", stdout);
		freopen(out, "w", stderr);
		setbuf(stderr, NULL);

//	NOTE: Using undocumented constructor accepting FILE*
		std::ifstream(stdin).swap(ifs);
		std::ofstream(stdout).swap(ofs);

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

		ifs.close();
		ofs.close();

		fclose(stdin);
		fclose(stdout);
		fclose(stderr);
	}
};

int main(int argc, char** argv)
{
	sandbox::BrokerServices* broker_service = sandbox::SandboxFactory::GetBrokerServices();
	sandbox::ResultCode result;

	int ret = 0;

	if(broker_service != NULL) {

		if ((result = broker_service->Init())) {
			std::cerr << "Initialization of broker service failed." << std::endl;
			return 1;
		}

		sandbox::TargetPolicy* policy = broker_service->CreatePolicy();
		policy->SetJobLevel(sandbox::JOB_LOCKDOWN, 0);
		policy->SetTokenLevel(sandbox::USER_RESTRICTED_SAME_ACCESS, sandbox::USER_LOCKDOWN);
		policy->SetAlternateDesktop(true);
		policy->SetDelayedIntegrityLevel(sandbox::INTEGRITY_LEVEL_LOW);
//		policy->AddRule(sandbox::TargetPolicy::SUBSYS_FILES,
//		                  sandbox::TargetPolicy::FILES_ALLOW_ANY, L"d:\\home\\atarashi\\work-git\\ccf\\sandbox.log");
		PROCESS_INFORMATION target_;
		sandbox::ResultCode result = broker_service->SpawnTarget(L".\\sandbox.exe", L"", policy, &target_);
		policy->Release();
		policy = NULL;

		if(result != sandbox::SBOX_ALL_OK) {
			std::cout << "SpawnTarget failed." << std::endl;
			return -1;
	    }

		::ResumeThread(target_.hThread);

		::CloseHandle(target_.hProcess);
		::CloseHandle(target_.hThread);

	    broker_service->WaitForAllTargets();

	} else {

		// SetStdHandle() does not work as expected
		// Before locked-down, we can access arbitrary files.
		StdHandleSaver shs("d:\\home\\atarashi\\work-git\\ccf\\sandboxin.txt", "d:\\home\\atarashi\\work-git\\ccf\\sandboxout.txt");

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
