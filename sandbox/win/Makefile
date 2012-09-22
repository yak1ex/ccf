!IFDEF CPU_OK
CXXFLAGS=$(CXXFLAGS) /DCPU_OK
!ELSEIFDEF CPU_BAD
CXXFLAGS=$(CXXFLAGS) /DCPU_BAD
!ELSEIFDEF MEM_OK
CXXFLAGS=$(CXXFLAGS) /DMEM_OK
!ELSEIFDEF MEM_BAD
CXXFLAGS=$(CXXFLAGS) /DMEM_BAD
!ENDIF

all: sandbox-compiler.exe sandbox.exe test.exe

sandbox-compiler.exe: sandbox-compiler.obj
	cl /MDd /Fesandbox-compiler.exe /EHsc /I..\..\chromium sandbox-compiler.obj  ..\..\sandbox-win-standalone\Debug\sandbox-win-standalone.lib advapi32.lib user32.lib shell32.lib dbghelp.lib psapi.lib

sandbox-compiler.obj: sandbox.cpp
	cl /c /D_DEBUG /D_WIN32_WINNT=0x0602 /DWINVER=0x0602 /DWIN32 /D_WINDOWS /DNOMINMAX /DPSAPI_VERSION=1 /DWIN32_LEAN_AND_MEAN /D_CRT_SECURE_NO_DEPRECATE /D_SCL_SECURE_NO_DEPRECATE /DSANDBOX_COMPILER /MDd /EHsc /I..\..\chromium /Fosandbox-compiler.obj sandbox.cpp

sandbox.exe: sandbox.obj test__.obj ..\..\sandbox-win-standalone\Debug\sandbox-win-standalone.lib
	cl /MDd sandbox.obj test__.obj ..\..\sandbox-win-standalone\Debug\sandbox-win-standalone.lib advapi32.lib user32.lib shell32.lib dbghelp.lib psapi.lib

sandbox.obj: sandbox.cpp
	cl /c /D_DEBUG /D_WIN32_WINNT=0x0602 /DWINVER=0x0602 /DWIN32 /D_WINDOWS /DNOMINMAX /DPSAPI_VERSION=1 /DWIN32_LEAN_AND_MEAN /D_CRT_SECURE_NO_DEPRECATE /D_SCL_SECURE_NO_DEPRECATE /MDd /EHsc /I..\..\chromium sandbox.cpp

test__.obj: test_.obj
	objcopy --redefine-sym _main=_main_ test_.obj test__.obj

test_.obj: test.cpp
	cl /c $(CXXFLAGS) /MDd /EHsc /Fotest_.obj test.cpp

test.obj: test.cpp
	cl /c $(CXXFLAGS) /MDd /EHsc /Fotest.obj test.cpp

test.exe: test.obj
	cl /MDd /EHsc test.obj

clean:
	del *.exe *.obj
