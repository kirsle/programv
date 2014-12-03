@echo off
echo Alice tester
echo       reads   testcase.txt
echo       creates testcase.log, aiml.log, user1.data
echo Please be patient...
if exist data\user1.data echo y | del data\user1.data
if exist aiml.log echo y | del aiml.log
perl shell.pl -d -f server-test.properties < testcase.txt > testcase.log
echo Done!
pause
