# SE-RRDtool
SE-RRDtool is an extension to RRDtool,  which is high performance data logging and graphing system. The goal is to enhance the semantics in RRD to facilitate semantic based monitoring data retrieval and to improve the inter-operability of monitoring  systems and analysis software.

Now the installzation is only available for Debian/Ubuntu.

--------------------------------

Dependency:
Packages will get added through dependencies.

  apt-get install libpango1.0-dev libxml2-dev libcurl4-gnutls-dev libjson0 libjson0-dev libjson0-dbg git

Just make sure you have the privilege to install them.

--------------------------------

Download:
Before downloading SE-RRDtool, please create a new folder for it, here we call it $SERRD_PATH.

  cd $SERRD_PATH
  git clone https://github.com/utd-cloudlib/SE-RRDtool

All the source code will be downloaded under $SERRD_PATH/SE-RRDtool.

--------------------------------

Install:
To install it, type:

  cd $SERRD_PATH/SE-RRDtool/SERRDtool-1.4.9
  ./configure --prefix=$INSTALL_DIR LIBS="-lcurl -ljson -lxml2" && make && make install

$SERRD_PATH is the path where SE-RRDtool source code is downloaded in previous step. $INSTALL_DIR is the repository you wan to install SERRDtool.

--------------------------------

Config:
The 
1. Config for Tomcat

  cd $INSTALL_PATH
  wget http://www.us.apache.org/dist/tomcat/tomcat-7/v7.0.73/bin/apache-tomcat-7.0.73.tar.gz
  tar -xvzf apache-tomcat-7.0.73.tar.gz
  cd apache-tomcat-7.0.73

2. Config for SERRD

  cd $SERRD_PATH/SE-RRDtool
  cp -r SERRDtool-webserver/ $INSTALL_PATH/apache-tomcat-7.0.73/webapps/
  mv SERRDtool-webserver/ SERRDtool
 
-------------------------------- 

To start over:

  make clean

This removes the executable file, as well as old .o object files.

--------------------------------

SERRDtool has two modes: normal mode and SE model. Lagacy system can still use it as original RRDtool.
For SE model, the difference from the original CLI is: add "-se unitName -un unit -et entityType -en entity" after the rrdtool utilities, such "create", "fetch", "update", etc.
For example, the command to create an rrd file is:
rrdtool create -se unitName -un unit -et entityType -en entity [normal parameters]

