#include <iostream>
#include <fstream>
#include <vector>
#include <numeric>

int main(int argc, char** argv)
{
#if defined(MEM_OK) || defined(MEM_BAD)
#if defined(MEM_OK)
	std::vector<int> v(218*1024); // OK
#endif
#if defined(MEM_BAD)
	std::vector<int> v(219*1024); // Bad
#endif
	v.back() = 5;
#endif

#if defined(CPU_OK) || defined(CPU_BAD)
#if defined(CPU_OK)
	for(int i=0;i<100000000;++i); // OK
#endif
#if defined(CPU_BAD)
	for(int i=0;i<1000000000;++i); // Bad
#endif
#endif

	int n;
	std::cin >> n;
	std::vector<int> v(n);
	for(int i=0;i<n;++i) std::cin >> v[i];
	std::cout << std::accumulate(v.begin(), v.end(), 0) << std::endl;

// TODO: Set appropriate path automatically
	std::ofstream ofs("d:\\home\\atarashi\\work-git\\ccf\\sandbox\\win\\sandbox.log", std::ios::out|std::ios::app);
	ofs << "Test" << std::endl;

	return 0;
}
