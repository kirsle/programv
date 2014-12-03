#!/bin/sh

#	rm ./logs/chat.log
#	rm ./logs/chat.xml
#	./server.sh < testcase.txt

echo 'Alice tester'
echo '      reads   testcase.txt'
echo '      creates testcase.log, aiml.log, user1.data'
echo 'Please be patient...'

if test -e ./data/user1.data ; then
	rm ./data/user1.data
fi

if test -e ./aiml.log ; then
	rm ./aiml.log
fi

./shell.pl -d -f server-test.properties < testcase.txt > testcase.log

echo 'Done!'
