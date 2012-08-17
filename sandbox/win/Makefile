sandbox.exe: sandbox.obj test_.obj ..\..\sandbox-win-standalone\Debug\sandbox-win-standalone.lib
	cl /MDd sandbox.obj test_.obj ..\..\sandbox-win-standalone\Debug\sandbox-win-standalone.lib advapi32.lib user32.lib shell32.lib dbghelp.lib psapi.lib

sandbox.obj: sandbox.cpp
	cl /c /D_DEBUG /D_WIN32_WINNT=0x0602 /DWINVER=0x0602 /DWIN32 /D_WINDOWS /DNOMINMAX /DPSAPI_VERSION=1 /DWIN32_LEAN_AND_MEAN /D_CRT_SECURE_NO_DEPRECATE /D_SCL_SECURE_NO_DEPRECATE /MDd /EHsc /I..\..\chromium sandbox.cpp

test_.obj: test.obj
	objcopy --redefine-sym _main=_main_ test.obj test_.obj

test.obj: test.cpp
	cl /c /MDd /EHsc test.cpp

clean:
	del *.exe *.obj
