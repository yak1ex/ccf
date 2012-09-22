#include <iostream>
#include <fstream>
#include <vector>
#include <numeric>
#include <cstdlib>
#include <cstdio>

int main(int argc, char** argv)
{
#if defined(MEM_OK) || defined(MEM_BAD)
#if defined(MEM_OK)
	std::vector<int> vv(220*1024); // OK
#endif
#if defined(MEM_BAD)
	std::vector<int> vv(221*1024); // Bad
#endif
	vv.back() = 5;
#endif

#if defined(CPU_OK) || defined(CPU_BAD)
#if defined(CPU_OK)
	for(int i=0;i<100000000;++i); // OK
#endif
#if defined(CPU_BAD)
	for(int i=0;i<1000000000;++i) // Bad
		for(int j=0;j<1000000000;++j);
#endif
#endif

	int v[5] = { 3, 4, 5, 6, 7 };
	std::cout << std::accumulate(v, v+sizeof(v)/sizeof(v[0]), 0) << std::endl;
	unlink("sandbox.log");
	system("cl.exe /? > help.txt 2>&1");

	return 0;
}
