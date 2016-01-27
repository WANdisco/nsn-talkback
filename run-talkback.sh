#!/bin/bash

###########################################################################
# Download and run nsn-talkback
###########################################################################

echo "Checking wget ..."
which wget
if [[ $? != 0 ]]; then
  echo "Sorry, but wget is not installed. Please install it and run again."
  exit 1
fi

echo "Checking tar ..."
which tar
if [[ $? != 0 ]]; then
  echo "Sorry, but tar is not installed. Please install it and run again."
  exit 1
fi

echo "Downloading talkback agent..."
wget -qO- https://github.com/WANdisco/nsn-talkback/archive/master.tar.gz | tar -xzmC /tmp

echo "Starting talkback agent..."
if [[ -f /tmp/nsn-talkback-master/talkback.sh ]]; then
  (
    cd /tmp/nsn-talkback-master
    sh ./talkback.sh
  )
else
  echo "Can't find downloaded talkback agent."
  exit 1
fi
