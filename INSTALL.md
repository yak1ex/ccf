C++ Compiler Farm Install Memo
==============================

2 AWS instances, one for Linux and another for Windows, are requried.

Linux part
----------

### NOTES ###

Before installing i386 compilers, it is necessary to build perl XS modules on x86_64.

### PROCEDURE ###

```
# MISC
sudo apt-get install build-essential git libxml2-dev zlib1g-dev
# CCF(ref)
git clone https://github.com/yak1ex/ccf
# PERL
curl -L http://cpanmin.us | perl - App::cpanminus -S
cpanm -S App::installdeps
#installdeps -i 'cpanm -S' ccf
# As some modules should fail, need to check results
# ObjectFile::Tiny, CCF::* and Win32::Codepage::Simple can be ignored
cpanm -S `installdeps -n ccf` > log 2>&1
cpanm -S Twiggy
cpanm -S EV # optional
cpanm -S http://search.cpan.org/CPAN/authors/id/P/PF/PFIG/Net-Amazon-S3-0.59.tar.gz # downgrade due to conflict with 0.60
- # Hack to suppress warnings
  - # enclose enum argument by [] (line numbers for v0.59)
  - sudo vi +19 /usr/lib/perl5/site_perl/5.14/Net/Amazon/S3/Client/Object.pm
  - sudo vi +13 /usr/lib/perl5/site_perl/5.14/Net/Amazon/S3/Request.pm
  - sudo vi +19 /usr/lib/perl5/site_perl/5.14/Net/Amazon/S3/HTTPRequest.pm
# GCC
sudo add-apt-repository ppa:ubuntu-toolchain-r/test

sudo apt-get update
sudo apt-get install g++-4.4:i386 g++-4.5:i386 g++-4.6:i386 g++-4.7:i386 g++-4.8:i386
# CLANG
sudo add-apt-repository ppa:h-rayflood/llvm

sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get install clang-3.0:i386 clang-3.1:i386 clang-3.2:i386 clang-3.3:i386 clang-3.4:i386
Yes, do as I say!
# USER
# add ccf user and group
sudo vipw
sudo vipw -s
sudo vi /etc/group
sudo mkdir /home/ccf
# configure ssh
# ...
sudo chown -R ccf:ccf /home/ccf
# configure git
# as [ccf]
# CCF
git clone https://github.com/yak1ex/ccf
cd ccf
git checkout master
cd ..
git clone https://github.com/yak1ex/ccf ccf.work
vi ccf/compile_server/config.yaml
# edit { GLOBAL: { bucket: xxx } }
vi ccf/web_frontend/config.yaml
# edit { bucket: xxx, backend: [xxx] }
cd ccf.work/sandbox/linux
make CXX=g++-4.4 CC=gcc-4.4
cd ../../../ccf/sandbox/linux
make CXX=g++-4.4 CC=gcc-4.4
cd ../../..
# boost
wget http://downloads.sourceforge.net/project/boost/boost/1.56.0/boost_1_56_0.tar.bz2
tar xjf boost_1_56_0.tar.bz2
sudo cp -pR boost_1_56_0/boost /usr/include/boost
```

Windows part
------------

### PROCEDURE ###

- Install VC/VS express editions
- Install x86 cygwin including
  - git
  - gcc-g++
  - inetutils (optional, telnet for debug)
  - libxml2-devel
  - make
  - perl
- git clone https://github.com/yak1ex/ccf
- (cd ccf; git checkout master; cd ..)
- git clone https://github.com/yak1ex/ccf ccf.work
- curl -L http://cpanmin.us/ | perl - App::cpanminus
- # strip -4 from gcc-4 and so on
  - vi /usr/lib/perl5/5.14/i686-cygwin-threads-64int/Config.pm
  - vi /usr/lib/perl5/5.14/i686-cygwin-threads-64int/Config_heavy.pl
- cpanm App::installdeps
- cpanm --notest Test::SharedFork # blocked
- installdeps ccf.work/compile_server ccf.work/lib
- cpanm http://search.cpan.org/CPAN/authors/id/P/PF/PFIG/Net-Amazon-S3-0.59.tar.gz # downgrade due to conflict with 0.60
- # Hack to suppress warnings
  - # enclose enum argument by [] (line numbers for v0.59)
  - vi +19 /usr/lib/perl5/site_perl/5.14/Net/Amazon/S3/Client/Object.pm
  - vi +13 /usr/lib/perl5/site_perl/5.14/Net/Amazon/S3/Request.pm
  - vi +19 /usr/lib/perl5/site_perl/5.14/Net/Amazon/S3/HTTPRequest.pm
- cpanm EV # optional
- for each VC/VS installation
  - execute command prompt corresponding to the installation
  - # for VC8(2005), need to adjust environmwent variables
    - set "INCLUDE=C:\Program Files\Microsoft SDKs\Windows\v6.0A\Include;%INCLUDE%"
    - set "LIB=C:\Program Files\Microsoft SDKs\Windows\v6.0A\Lib;%LIB%"
  - cd ~/ccf/sandbox/win
  - nmake -f Makefile.lib
  - nmake sandbox.obj
  - # for one of VC/VS installation
    - nmake sandbox.exe sandbox-compiler.exe
  - mkdir vcXX
  - copy sandbox.obj vcXX
  - copy out\sandbox-win-standalone.lib vcXX
  - rmdir /s /q out
  - del *.obj
- Repeat for ~/ccf.work/sandbox/win or copy ccf/sandbox/win/{vc*,sandbox*.exe} to ccf.work/sandbox/win
- Change firewall settings to allow communicating with compile_server. Default port is 8888.
- Place boost headers
  - wget http://downloads.sourceforge.net/project/boost/boost/1.56.0/boost_1_56_0.tar.bz2
  - tar xjf boost_1_56_0.tar.bz2
  - copy boost_1_56_0/boost to c:/boost/boost
