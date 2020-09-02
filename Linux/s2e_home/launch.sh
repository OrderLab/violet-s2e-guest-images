#!/bin/sh

# S2E Selective Symbolic Execution Platform
#
# Copyright (c) 2017, Dependable Systems Laboratory, EPFL
# Copyright (c) 2017, Cyberhaven
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -ex

# Install 32-bit user space for 64-bit kernels
install_i386() {
    if uname -a | grep -q x86_64; then
        sudo dpkg --add-architecture i386
        sudo apt-get update

        # libelf is required for s2e.so
        sudo apt-get -y install gcc-multilib g++-multilib libc6-dev-i386 lib32stdc++-6-dev libstdc++6:i386 \
            libelf1:i386
    fi
}


# Install systemtap from source
# The one that's packaged does not support our kernel
# Note: systemtap requires a lot of memory to compile, so we need swap
install_systemtap() {
    git clone git://sourceware.org/git/systemtap.git
    cd systemtap
    git checkout release-3.2
    cd ..

    mkdir systemtap-build
    cd systemtap-build
    ../systemtap/configure --disable-docs
    make -j2
    sudo make install
    cd ..
}

install_squid() {
 cd /home/s2e
 wget -nc http://www.squid-cache.org/Versions/v4/squid-4.1.tar.xz
 tar -xvf squid-4.1.tar.xz
 cd squid-4.1
 mkdir build
 cd build
 ../configure --prefix=/home/s2e/software/squid/4.1 --disable-arch-native
 make -j2
 make install
 cd /home/s2e
 # Delete source and build directory to save space
 rm -rf squid-4.1
}


# Install postgresql from source
# Add for VIOLET project
install_postgresql() {
 sudo apt-get -y install cmake vim libncurses-dev zlib1g-dev  libreadline-gplv2-dev
 cd /home/s2e
 wget -nc https://ftp.postgresql.org/pub/source/v11.0/postgresql-11.0.tar.gz
 tar -zxvf postgresql-11.0.tar.gz
 rm -rf 11.0/
 mv postgresql-11.0 11.0
 cd ./11.0
 mkdir ./build
 cd ./build
 mkdir -p /home/s2e/software/postgresql/11.0
 sleep 2
../configure --prefix=/home/s2e/software/postgresql/11.0 --enable-depend --enable-cassert --enable-debug CFLAGS="-ggdb -O0"
 make -j 4
 make install
 cd ../.. 
 cd software/postgresql/11.0
 ./bin/initdb -D data
 ./bin/postgres --config-file=data/postgresql.conf -D data/ &
 sleep 10 
 ./bin/createdb test
 ./bin/psql test << EOF
 CREATE TABLE tbl(id SERIAL,col INT NOT NULL, PRIMARY KEY (id));
 INSERT INTO tbl(col) VALUES(1);
 INSERT INTO tbl(col) VALUES(2);
 INSERT INTO tbl(col) VALUES(3);
 INSERT INTO tbl(col) VALUES(4);
 INSERT INTO tbl(col) VALUES(5);
 INSERT INTO tbl(col) VALUES(6);
 INSERT INTO tbl(col) VALUES(7);
 INSERT INTO tbl(col) VALUES(8);
 INSERT INTO tbl(col) VALUES(9);
 INSERT INTO tbl(col) VALUES(10);
 create TABLE violet_B(id int primary key,col2 int, app varchar(20), text varchar(50),school varchar(10));
 insert into violet_B select generate_series(1,1000) as key, (random()*(10^4))::integer, 'app_A',random()::varchar(50),random()::varchar(10);
 insert into violet_B select generate_series(1001,20000) as key, (random()*(10^4))::integer, 'app_B',random()::varchar(50),random()::varchar(10);
 insert into violet_B select generate_series(20001,21000) as key, (random()*(10^4))::integer, 'app_A',random()::varchar(50),random()::varchar(10);
 insert into violet_B select generate_series(21001,40000) as key, (random()*(10^4))::integer, 'app_B',random()::varchar(50),random()::varchar(10);
 insert into violet_B select generate_series(41001,42000) as key, (random()*(10^4))::integer, 'app_A',random()::varchar(50),random()::varchar(10);
 insert into violet_B select generate_series(42001,100000) as key, (random()*(10^4))::integer, 'app_B',random()::varchar(50),random()::varchar(10);
 insert into violet_B select generate_series(100001,200000) as key, (random()*(10^4))::integer, random()::varchar(20),random()::varchar(50),random()::varchar(10);
 create TABLE violet_A(id int primary key,event_id int, phone varchar(10), name varchar(22));
 insert into violet_A select generate_series(1,100000) as key, (random()*(10^5))::integer,random()::varchar(10), random()::varchar(20);
EOF
 ./bin/pg_ctl -D data stop
 cd /home/s2e
 # Delete source and build directory to save space
 rm -rf 11.0
}

# Install apache from source
# Add for VIOLET project
install_apache() {
 sudo apt-get -y install libapr1-dev libaprutil1-dev libpcre3-dev liblua5.3-dev
 cd /home/s2e
 wget -nc https://archive.apache.org/dist/httpd/httpd-2.4.38.tar.gz
 tar -zxvf httpd-2.4.38.tar.gz
 mv httpd-2.4.38  2.4
 wget -nc http://mirrors.gigenet.com/apache//apr/apr-1.6.5.tar.gz
 tar -zxvf apr-1.6.5.tar.gz
 cd apr-1.6.5
 ./configure --prefix=/home/s2e/software/apr
 make 
 make install
 cd ..
 wget -nc http://mirrors.gigenet.com/apache//apr/apr-util-1.6.1.tar.gz
 tar -zxvf apr-util-1.6.1.tar.gz
 cd apr-util-1.6.1
 ./configure --prefix=/home/s2e/software/apr-util --with-apr=/home/s2e/software/apr
 make 
 make install
 cd ..
 wget -nc https://ftp.pcre.org/pub/pcre/pcre-8.42.tar.gz
 tar -zxvf pcre-8.42.tar.gz
 cd pcre-8.42
 ./configure --prefix=/home/s2e/software/pcre --disable-shared --with-pic 
 make 
 make install
 cd ..
 cd 2.4
 mkdir ./build-debug
 cd ./build-debug
 mkdir -p /home/s2e/software/httpd/2.4
 sleep 2
 CFLAGS="-O0" ../configure --prefix=/home/s2e/software/httpd/2.4 --with-apr=/home/s2e/software/apr --with-apr-util=/home/s2e/software/apr-util --with-pcre=/home/s2e/software/pcre
 make -j 4
 make install
 cd ../..
 cd software/httpd/2.4
 cp /home/s2e/mysql_configuration/httpd.conf conf/
 ./bin/httpd -k start &
 sleep 2
 ./bin/httpd -k stop
 cd /home/s2e 
 # Delete source and build directory to save space
 rm -rf 2.4 apr-1.6.5 apr-util-1.6.1 pcre-8.42
}

# Install mysql from source
# Add for VIOLET project
#install_mysql
install_mysql() {
 sudo apt-get -y install cmake vim libncurses-dev zlib1g-dev libreadline-gplv2-dev
 cd /home/s2e
 if [ ! -d mysql_configuration ]; then
   git clone https://github.com/gongxini/mysql_configuration.git
 fi
 wget -nc https://downloads.mysql.com/archives/mysql-5.5/mysql-5.5.59.tar.gz
 tar -zxvf mysql-5.5.59.tar.gz
 rm -rf 5.5.59/
 mv mysql-5.5.59 5.5.59
 cd ./5.5.59
 mkdir ./build
 cd ./build
 mkdir -p /home/s2e/software/mysql/5.5.59/data
 sleep 2
 cmake ..  -DCMAKE_INSTALL_PREFIX=/home/s2e/software/mysql/5.5.59 -DMYSQL_DATADIR=/home/s2e/software/mysql/5.5.59/data -DWITH_DEBUG=1 -DMYSQL_MAINTAINER_MODE=false
 make -j 4
 make install
 cd ../..
 cp mysql_configuration/my.cnf software/mysql/5.5.59/
 cd software/mysql/5.5.59
 scripts/mysql_install_db  --basedir=/home/s2e/software/mysql/5.5.59 --datadir=/home/s2e/software/mysql/5.5.59/data
 ./bin/mysqld --defaults-file=my.cnf --one-thread &
 sleep 60
 ./bin/mysql -S mysqld.sock << EOF
 use test;
 CREATE TABLE tbl(id INT NOT NULL AUTO_INCREMENT,col INT NOT NULL, PRIMARY KEY (id)) Engine = InnoDB;
 INSERT INTO tbl(col) VALUES(11);
 INSERT INTO tbl(col) VALUES(12);
 INSERT INTO tbl(col) VALUES(13);
 INSERT INTO tbl(col) VALUES(14);
 INSERT INTO tbl(col) VALUES(15);
 INSERT INTO tbl(col) VALUES(16);
 INSERT INTO tbl(col) VALUES(17);
 INSERT INTO tbl(col) VALUES(18);
 INSERT INTO tbl(col) VALUES(19);
 INSERT INTO tbl(col) VALUES(20);
 INSERT INTO tbl(col) VALUES(21);
 INSERT INTO tbl(col) VALUES(22);
 INSERT INTO tbl(col) VALUES(23);
 INSERT INTO tbl(col) VALUES(24);
 INSERT INTO tbl(col) VALUES(25);
 INSERT INTO tbl(col) VALUES(26);
 INSERT INTO tbl(col) VALUES(27);
 INSERT INTO tbl(col) VALUES(28);
 INSERT INTO tbl(col) VALUES(29);
 INSERT INTO tbl(col) VALUES(30);
 CREATE TABLE tbl1(id INT NOT NULL AUTO_INCREMENT,col INT NOT NULL, PRIMARY KEY (id)) Engine = MyISAM;
 INSERT INTO tbl1(col) VALUES(31);
 INSERT INTO tbl1(col) VALUES(32);
 INSERT INTO tbl1(col) VALUES(33);
 INSERT INTO tbl1(col) VALUES(34);
EOF
 ./bin/mysqladmin -S mysqld.sock -u root shutdown
 cd /home/s2e
 # Delete build and source directory to save space
 rm -rf 5.5.59
}


# Install mysql from source
# Add for VIOLET project
install_mysql_8() {
 sudo apt-get -y install cmake vim libssl-dev pkg-config libncurses-dev zlib1g-dev  libreadline-gplv2-dev
 if [ ! -d mysql_configuration ]; then
   git clone https://github.com/gongxini/mysql_configuration.git
 fi
 wget -nc https://downloads.mysql.com/archives/mysql-8.0/mysql-8.0.16.tar.gz 
 tar -zxvf mysql-8.0.16.tar.gz
 rm -rf 8.0.16/
 mv mysql-8.0.16 8.0.16
 cd ./8.0.16
 mkdir ./build
 cd ./build
 mkdir -p /home/s2e/software/mysql/8.0.16/data
 sleep 2
  cmake .. -DCMAKE_INSTALL_PREFIX=/home/s2e/software/mysql/8.0.16 -DMYSQL_DATADIR=/home/s2e/software/mysql/8.0.16/data -DSYSCONFDIR=/home/s2e/software/mysql/8.0.16/etc  -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost
 make -j 4
 make install
 cd ../..
 cp mysql_configuration/my-8.0.cnf software/mysql/8.0.16/my.cnf
 cd software/mysql/8.0.16
 ./bin/mysqld --initialize --datadir=/home/s2e/software/mysql/8.0.16/data/ --basedir=/home/s2e/software/mysql/8.0.16
 ./bin/mysqld --defaults-file=my.cnf  &
 sleep 20
 ./bin/mysql -S mysqld.sock << EOF
 create database test;
 use test;
 CREATE TABLE tbl(id INT NOT NULL AUTO_INCREMENT,col INT NOT NULL, PRIMARY KEY (id)) Engine = InnoDB;
 INSERT INTO tbl(col) VALUES(11);
 INSERT INTO tbl(col) VALUES(12);
 INSERT INTO tbl(col) VALUES(13);
 INSERT INTO tbl(col) VALUES(14);
 INSERT INTO tbl(col) VALUES(15);
 INSERT INTO tbl(col) VALUES(16);
 INSERT INTO tbl(col) VALUES(17);
 INSERT INTO tbl(col) VALUES(18);
 INSERT INTO tbl(col) VALUES(19);
 INSERT INTO tbl(col) VALUES(20);
 INSERT INTO tbl(col) VALUES(21);
 INSERT INTO tbl(col) VALUES(22);
 INSERT INTO tbl(col) VALUES(23);
 INSERT INTO tbl(col) VALUES(24);
 INSERT INTO tbl(col) VALUES(25);
 INSERT INTO tbl(col) VALUES(26);
 INSERT INTO tbl(col) VALUES(27);
 INSERT INTO tbl(col) VALUES(28);
 INSERT INTO tbl(col) VALUES(29);
 INSERT INTO tbl(col) VALUES(30);
 CREATE TABLE tbl1(id INT NOT NULL AUTO_INCREMENT,col INT NOT NULL, PRIMARY KEY (id)) Engine = MyISAM;
 INSERT INTO tbl1(col) VALUES(31);
 INSERT INTO tbl1(col) VALUES(32);
 INSERT INTO tbl1(col) VALUES(33);
 INSERT INTO tbl1(col) VALUES(34);
EOF
 ./bin/mysqladmin -S mysqld.sock -u root shutdown
 cd /home/s2e
 # Delete source and build directory to save space
 rm -rf 8.0.16/
}

# Install kernels last, the cause downgrade of libc,
# which will cause issues when installing other packages
install_kernel() {
    sudo dpkg -i *.deb

    MENU_ENTRY="$(grep menuentry /boot/grub/grub.cfg  | grep s2e | cut -d "'" -f 2 | head -n 1)"
    echo "Default menu entry: $MENU_ENTRY"
    echo "GRUB_DEFAULT=\"1>$MENU_ENTRY\"" | sudo tee -a /etc/default/grub
    sudo update-grub
}

has_cgc_kernel() {
    if ls *.deb | grep -q ckt32-s2e; then
        echo 1
    else
        echo 0
    fi
}

# Install the prerequisites for cgc packages
install_apt_packages() {
    APT_PACKAGES="
    python-apt
    python-crypto
    python-daemon
    python-lockfile
    python-lxml
    python-matplotlib
    python-yaml
    tcpdump
    "

    sudo apt-get -y install ${APT_PACKAGES}

    # This package no longer exists on recent debian version
    wget http://ftp.us.debian.org/debian/pool/main/p/python-support/python-support_1.0.15_all.deb
    sudo dpkg -i python-support_1.0.15_all.deb
}

install_cgc_packages() {
    CGC_PACKAGES="
    binutils-cgc-i386_2.24-10551-cfe-rc8_i386.deb
    cgc2elf_10551-cfe-rc8_i386.deb
    libcgcef0_10551-cfe-rc8_i386.deb
    libcgcdwarf_10551-cfe-rc8_i386.deb
    readcgcef_10551-cfe-rc8_i386.deb
    python-defusedxml_10551-cfe-rc8_all.deb
    libcgc_10551-cfe-rc8_i386.deb
    cgc-network-appliance_10551-cfe-rc8_all.deb
    cgc-service-launcher_10551-cfe-rc8_i386.deb
    poll-generator_10551-cfe-rc8_all.deb
    cb-testing_10551-cfe-rc8_all.deb
    cgc-release-documentation_10560-cfe-rc8_all.deb
    cgcef-verify_10551-cfe-rc8_all.deb
    cgc-pov-xml2c_10551-cfe-rc8_i386.deb
    strace-cgc_4.5.20-10551-cfe-rc8_i386.deb
    libpov_10551-cfe-rc8_i386.deb
    clang-cgc_3.4-10551-cfe-rc8_i386.deb
    cgc-virtual-competition_10551-cfe-rc8_all.deb
    magic-cgc_10551-cfe-rc8_all.deb
    services-cgc_10551-cfe-rc8_all.deb
    linux-image-3.13.11-ckt32-cgc_10551-cfe-rc8_i386.deb
    linux-libc-dev_10551-cfe-rc8_i386.deb
    "

    local CUR_DIR
    CUR_DIR="$(pwd)"

    # Download packages in temp folder
    cd /tmp

    # Install the CGC packages
    for PACKAGE in ${CGC_PACKAGES}; do
        wget --no-check-certificate https://cgcdist.s3.amazonaws.com/release-final/deb/${PACKAGE}
        sudo dpkg -i --force-confnew ${PACKAGE}
        rm -f ${PACKAGE}
    done

    cd "$CUR_DIR"
}

sudo apt-get update
# install_mysql_8
install_postgresql
install_mysql
install_i386
# install_apache 
#install_systemtap
# install_squid
# Install CGC tools if we have a CGC kernel
if [ $(has_cgc_kernel) -eq 1 ]; then
    install_apt_packages
    install_cgc_packages
fi
install_kernel

# QEMU will stop (-no-reboot)
sudo reboot
