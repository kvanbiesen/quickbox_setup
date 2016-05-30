#!/bin/bash
#
# [QuickBox Installation Script]
#
# GitHub:   https://github.com/Swizards/QuickBox
# Author:   Swizards.net https://swizards.net
# URL:      https://plaza.quickbox.io
#
# QuickBox Copyright (C) 2016 Swizards.net
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
# find server hostname and repo location for quickbox configuration
#################################################################################
#################################################################################
#Script Console Colors
black=$(tput setaf 0); red=$(tput setaf 1); green=$(tput setaf 2); yellow=$(tput setaf 3);
blue=$(tput setaf 4); magenta=$(tput setaf 5); cyan=$(tput setaf 6); white=$(tput setaf 7);
on_red=$(tput setab 1); on_green=$(tput setab 2); on_yellow=$(tput setab 3); on_blue=$(tput setab 4);
on_magenta=$(tput setab 5); on_cyan=$(tput setab 6); on_white=$(tput setab 7); bold=$(tput bold);
dim=$(tput dim); underline=$(tput smul); reset_underline=$(tput rmul); standout=$(tput smso);
reset_standout=$(tput rmso); normal=$(tput sgr0); alert=${white}${on_red}; title=${standout};
sub_title=${bold}${yellow}; repo_title=${black}${on_green};
#################################################################################
if [[ -f /usr/bin/lsb_release ]]; then
    DISTRO=$(lsb_release -i | cut -d: -f2 | sed s/'^\t'//)
elif [ -f "/etc/redhat-release" ]; then
    DISTRO=$(egrep -o 'Fedora|CentOS|Red.Hat' /etc/redhat-release)
elif [ -f "/etc/debian_version" ]; then
    DISTRO=='Debian'
fi
#################################################################################

function _string() { perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15 ; }

function _bashrc() {
  cp templates/bashrc.template ~/.bashrc
}

# intro function (1)
function _intro() {
  echo
  echo
  echo "[${repo_title}QuickBox${normal}] ${title} QuickBox Seedbox Installation ${normal}  "
  echo
  echo

  echo "${green}Checking distribution ...${normal}"
  if [ ! -x  /usr/bin/lsb_release ]; then
    echo 'It looks like you are running $DISTRO, which is not supported by QuickBox.'
    echo 'Exiting...'
    exit 1
  fi
  echo "$(lsb_release -a)"
  echo
  dis="$(lsb_release -is)"
  rel="$(lsb_release -rs)"
  if [[ ! "${dis}" =~ ("Ubuntu"|"Debian") ]]; then
    echo "${dis}: ${alert} It looks like you are running $DISTRO, which is not supported by QuickBox ${normal} "
    echo 'Exiting...'
    exit 1
  elif [[ ! "${rel}" =~ ("16.04"|"8") ]]; then
    echo "${bold}${rel}:${normal} You do not appear to be running a supported $DISTRO release."
    echo 'Exiting...'
    exit 1
  fi
}


# check if root function (2)
function _checkroot() {
  if [[ $EUID != 0 ]]; then
    echo 'This script must be run with root privileges.'
    echo 'Exiting...'
    exit 1
  fi
  echo "${green}Congrats! You're running as root. Let's continue${normal} ... "
  echo
}

# check if create log function (3)
function _logcheck() {
  echo -ne "${bold}${yellow}Do you wish to write to a log file?${normal} (Default: ${green}${bold}Y${normal}) "; read input
    case $input in
      [yY] | [yY][Ee][Ss] | "" ) OUTTO="/root/quickbox.$PPID.log";echo "${bold}Output is being sent to /root/quickbox.$PPID.log${normal}" ;;
      [nN] | [nN][Oo] ) OUTTO="/dev/null 2>&1";echo "${cyan}NO output will be logged${normal}" ;;
    *) OUTTO="/root/quickbox.$PPID.log";echo "${bold}Output is being sent to /root/quickbox.$PPID.log${normal}" ;;
    esac
  if [[ ! -d /root/tmp ]]; then
    sed -i 's/noexec,//g' /etc/fstab
    mount -o remount /tmp >>"${OUTTO}" 2>&1
  fi
}

# primary partition question (4)
function _askpartition() {
  echo
  echo "##################################################################################"
  echo "#${bold} By default the QuickBox script will initiate a build using ${green}/${normal} ${bold}as the${normal}"
  echo "#${bold} primary partition for mounting quotas.${normal}"
  echo "#"
  echo "#${bold} Some providers, such as OVH and SYS force ${green}/home${normal} ${bold}as the primary mount ${normal}"
  echo "#${bold} on their server setups. So if you have an OVH or SYS server and have not"
  echo "#${bold} modified your partitions, it is safe to choose option ${yellow}2)${normal} ${bold}below.${normal}"
  echo "#"
  echo "#${bold} If you are not sure:${normal}"
  echo "#${bold} I have listed out your current partitions below. Your mountpoint will be"
  echo "#${bold} listed as ${green}/home${normal} ${bold}or ${green}/${normal}${bold}. ${normal}"
  echo "#"
  echo "#${bold} Typically, the partition with the most space assigned is your default.${normal}"
  echo "##################################################################################"
  echo
  lsblk
  echo
  echo -e "${bold}${yellow}1)${normal} / - ${green}root mount${normal}"
  echo -e "${bold}${yellow}2)${normal} /home - ${green}home mount${normal}"
  echo -ne "${bold}${yellow}What is your mount point for user quotas?${normal} (Default ${green}1${normal}): "; read version
  case $version in
    1 | "") primaryroot=root  ;;
    2) primaryroot=home  ;;
    *) primaryroot=root ;;
  esac
  echo "Using ${green}$primaryroot mount${normal} for quotas"
}

function _askcontinue() {
  echo
  echo "Press ${standout}${green}ENTER${normal} when you're ready to begin or ${standout}${red}Ctrl+Z${normal} to cancel" ;read input
  echo
}

# This function blocks an insecure port 1900 that may lead to
# DDoS masked attacks. Only remove this function if you absolutely
# need port 1900. In most cases, this is a junk port.
function _ssdpblock() {
  iptables -I INPUT 1 -p udp -m udp --dport 1900 -j DROP
}

# package and repo addition (5) _update and upgrade_
function _updates() {
  apt-get -y install lsb-release >>"${OUTTO}" 2>&1
  if [[ $DISTRO == Debian ]]; then
    cp templates/apt.sources/debian.template /etc/apt/sources.list
    apt-get --yes --force-yes install deb-multimedia-keyring >>"${OUTTO}" 2>&1
  else
    cp templates/apt.sources/ubuntu.template /etc/apt/sources.list
    apt-get -y -f install deb-multimedia-keyring >>"${OUTTO}" 2>&1
  fi

  if [[ $DISTRO == Debian ]]; then
    export DEBIAN_FRONTEND=noninteractive
    yes '' | apt-get update >>"${OUTTO}" 2>&1
    apt-get -y purge samba samba-common >>"${OUTTO}" 2>&1
    yes '' | apt-get upgrade >>"${OUTTO}" 2>&1
  else
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y update >>"${OUTTO}" 2>&1
    apt-get -y purge samba samba-common >>"${OUTTO}" 2>&1
    apt-get -y upgrade >>"${OUTTO}" 2>&1
  fi

  if [[ -e /etc/ssh/sshd_config ]]; then
    echo "Port 4747" /etc/ssh/sshd_config >> /dev/null 2>&1
    sed -i 's/Port 22/Port 4747/g' /etc/ssh/sshd_config
    service ssh restart >>"${OUTTO}" 2>&1
  fi

  # Create the service lock file directory
  cp install /install

}

# setting locale function (6)
function _locale() {
echo 'LANGUAGE="en_US.UTF-8"' >> /etc/default/locale
echo 'LC_ALL="en_US.UTF-8"' >> /etc/default/locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
  if [[ -e /usr/sbin/locale-gen ]]; then locale-gen >>"${OUTTO}" 2>&1
  else
    apt-get -y update >>"${OUTTO}" 2>&1
    apt-get install locales -y >>"${OUTTO}" 2>&1
    locale-gen >>"${OUTTO}" 2>&1
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    export LANGUAGE="en_US.UTF-8"
  fi
}

# package and repo addition (silently add php7) _add respo sources_
function _repos() {
  LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y >>"${OUTTO}" 2>&1;
}

# setting system hostname function (7)
function _hostname() {
echo -ne "Please enter a hostname for this server (${bold}Hit ${standout}${green}ENTER${normal} to make no changes${normal}): " ; read input
if [[ -z $input ]]; then
        echo "No hostname supplied, no changes made!!"
else
        hostname ${input}
        echo "${input}">/etc/hostname
        echo "hostname ${input}">> /etc/rc.local
        echo "Hostname set to ${input}"
fi
}

# package and repo addition (9) _install softwares and packages_
function _depends() {
  if [[ $DISTRO == Debian ]]; then
  apt-get -y update >>"${OUTTO}" 2>&1
  yes '' | apt-get install --force-yes build-essential fail2ban bc sudo screen zip irssi \
                                       unzip nano bwm-ng htop iotop git dos2unix subversion \
                                       dstat automake make mktorrent libtool libcppunit-dev \
                                       libssl-dev pkg-config libxml2-dev libcurl3 \
                                       libcurl4-openssl-dev libsigc++-2.0-dev apache2-utils autoconf \
                                       cron curl libxslt-dev libncurses5-dev yasm pcregrep apache2 \
                                       php5 php5-cli php-net-socket libdbd-mysql-perl libdbi-perl \
                                       fontconfig quota comerr-dev ca-certificates libfontconfig1-dev \
                                       libfontconfig1 rar unrar mediainfo php5-curl ifstat \
                                       libapache2-mod-php5 ttf-mscorefonts-installer checkinstall dtach cfv \
                                       libarchive-zip-perl libnet-ssleay-perl php5-geoip \
                                       openjdk-7-jre-headless openjdk-7-jre openjdk-7-jdk \
                                       libxslt1-dev libxslt1.1 libxml2 libffi-dev python-pip python-dev \
                                       libhtml-parser-perl libxml-libxml-perl libjson-perl libjson-xs-perl \
                                       libxml-libxslt-perl libapache2-mod-scgi python-software-properties \
                                       lshell vnstat vnstati openvpn >>"${OUTTO}" 2>&1
  else
  apt-get -y update >>"${OUTTO}" 2>&1
  apt-get -y install build-essential fail2ban bc sudo screen zip irssi unzip nano bwm-ng htop iotop git \
                     dos2unix subversion dstat automake make mktorrent libtool libcppunit-dev libssl-dev \
                     pkg-config libxml2-dev libcurl3 libcurl4-openssl-dev libsigc++-2.0-dev \
                     apache2-utils autoconf cron curl libapache2-mod-fastcgi libapache2-mod-geoip \
                     libxslt-dev libncurses5-dev yasm pcregrep apache2 php-net-socket \
                     libdbd-mysql-perl libdbi-perl php7.0 php7.0-fpm php7.0-mbstring php7.0-zip php7.0-mysql \
                     php7.0-curl php-memcached memcached php7.0-gd php7.0-json php7.0-mcrypt php7.0-opcache \
                     php7.0-xml php7.0-zip fontconfig quota comerr-dev ca-certificates libfontconfig1-dev \
                     libfontconfig1 rar unrar mediainfo ifstat libapache2-mod-php7.0 python-software-properties \
                     ttf-mscorefonts-installer checkinstall dtach cfv libarchive-zip-perl \
                     libnet-ssleay-perl openjdk-8-jre-headless openjdk-8-jre openjdk-8-jdk libxslt1-dev \
                     libxslt1.1 libxml2 libffi-dev python-pip python-dev libhtml-parser-perl libxml-libxml-perl \
                     libjson-perl libjson-xs-perl libxml-libxslt-perl libapache2-mod-scgi \
                     lshell vnstat vnstati openvpn >>"${OUTTO}" 2>&1
  fi
}

function _skel() {
  rm -rf /etc/skel
  mkdir /etc/skel
  cp -r templates/skel/. /etc/skel
  tar xzf sources/rarlinux-x64-5.3.0.tar.gz -C ./
  cp ./rar/*rar /usr/bin
  cp ./rar/*rar /usr/sbin
  rm -rf rarlinux*.tar.gz
  rm -rf ./rar
  wget -q http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz
  gunzip GeoLiteCity.dat.gz>>"${OUTTO}" 2>&1
  mkdir -p /usr/share/GeoIP>>"${OUTTO}" 2>&1
  rm -rf GeoLiteCity.dat.gz
  mv GeoLiteCity.dat /usr/share/GeoIP/GeoIPCity.dat>>"${OUTTO}" 2>&1
  (echo y;echo o conf prerequisites_policy follow;echo o conf commit)>/dev/null 2>&1|cpan Digest::SHA1 >>"${OUTTO}" 2>&1
  (echo y;echo o conf prerequisites_policy follow;echo o conf commit)>/dev/null 2>&1|cpan Digest::SHA >>"${OUTTO}" 2>&1
  # Setup mount points for Quotas
  if [[ ${primaryroot} == "root" ]]; then
    sed -i 's/errors=remount-ro/usrquota,errors=remount-ro/g' /etc/fstab
    apt-get install -y linux-image-extra-virtual >>"${OUTTO}" 2>&1
    mount -o remount / || mount -o remount /home >>"${OUTTO}" 2>&1
    quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
    quotaon -uv / >>"${OUTTO}" 2>&1
    service quota start >>"${OUTTO}" 2>&1
  else
    sed -i 's/errors=remount-ro/usrquota,errors=remount-ro/g' /etc/fstab
    apt-get install -y linux-image-extra-virtual >>"${OUTTO}" 2>&1
    mount -o remount /home >>"${OUTTO}" 2>&1
    quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
    quotaon -uv /home >>"${OUTTO}" 2>&1
    service quota start >>"${OUTTO}" 2>&1
  fi
  # Setup LShell configuration file
  cp templates/lshell.conf.template /etc/lshell.conf
}

# ban public trackers [iptables option] (8)
function _denyhosts() {
  echo -ne "${bold}${yellow}Block Public Trackers?${normal}: [${green}y${normal}]es or [n]o"; read responce
  case $responce in
    [yY] | [yY][Ee][Ss] | "")

  echo "[ ${red}Blocking public trackers${normal} ]"
  cp templates/trackers.template /etc/trackers
  cp templates/denypublic.template /etc/cron.daily/denypublic
  chmod +x /etc/cron.daily/denypublic
  cat templates/hostTrackers.template >> /etc/hosts
    ;;

    [nN] | [nN][Oo] ) echo "[ ${green}Allowing${normal} ]"
    ;;
  esac
}

# install ffmpeg question (9)
function _askffmpeg() {
  echo -ne "${bold}${yellow}Would you like to install ffmpeg? (Used for screenshots)${normal} [${green}y${normal}]es or [n]o: "; read responce
  case $responce in
    [yY] | [yY][Ee][Ss] | "" ) ffmpeg=yes ;;
    [nN] | [nN][Oo] ) ffmpeg=no ;;
    *) ffmpeg=yes ;;
  esac
}

# build function for ffmpeg (9.1)
function _ffmpeg() {
  if [[ ${ffmpeg} == "yes" ]]; then
    MAXCPUS=$(echo "$(nproc) / 2"|bc)
    cd /root/tmp
    if [[ -d /root/tmp/ffmpeg ]]; then rm -rf ffmpeg;fi
    ####---- Old source ----####
    #git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg >>"${OUTTO}" 2>&1
    ####---- New source ----####
    git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg >>"${OUTTO}" 2>&1
    ####---- Github Mirror source ----####
    #git clone git://github.com/FFmpeg/FFmpeg.git ffmpeg >>"${OUTTO}" 2>&1
    cd ffmpeg
    export FC_CONFIG_DIR=/etc/fonts
    export FC_CONFIG_FILE=/etc/fonts/fonts.conf
    ./configure --enable-libfreetype --enable-filter=drawtext --enable-fontconfig >>"${OUTTO}" 2>&1
    make -j${MAXCPUS} >>"${OUTTO}" 2>&1
    make install >>"${OUTTO}" 2>&1
    cp /usr/local/bin/ffmpeg /usr/bin >>"${OUTTO}" 2>&1
    cp /usr/local/bin/ffprobe /usr/bin >>"${OUTTO}" 2>&1
    rm -rf /root/tmp/ffmpeg >>"${OUTTO}" 2>&1
  fi
}

# ask what rtorrent version (10)
function _askrtorrent() {
  echo -e "1) rtorrent ${green}0.9.6${normal}"
  echo -e "2) rtorrent ${green}0.9.4${normal}"
  echo -e "3) rtorrent ${green}0.9.3${normal}"
  echo -ne "${bold}${yellow}What version of rtorrent do you want?${normal} (Default ${green}1${normal}): "; read version
  case $version in
    1 | "") RTVERSION=0.9.6;LTORRENT=0.13.6  ;;
    2) RTVERSION=0.9.4;LTORRENT=0.13.4  ;;
    3) RTVERSION=0.9.3;LTORRENT=0.13.3 ;;
    *) RTVERSION=0.9.6;LTORRENT=0.13.6 ;;
  esac
  echo "We will be using rtorrent-${green}$RTVERSION${normal}/libtorrent-${green}$LTORRENT${normal}"
  echo
}

# xmlrpc-c function (11)
function _xmlrpc() {
  cd /root/tmp
  if [[ -d /root/tmp/xmlrpc-c ]]; then rm -rf xmlrpc-c;fi
  cp -R "$REPOURL/xmlrpc-c_1-33-12/" .
  cd xmlrpc-c_1-33-12
  chmod +x configure
  ./configure --prefix=/usr --disable-cplusplus >>"${OUTTO}" 2>&1
  make >>"${OUTTO}" 2>&1
  chmod +x install-sh
  make install >>"${OUTTO}" 2>&1
}

# libtorent function (12)
function _libtorrent() {
  cd /root/tmp
  MAXCPUS=$(echo "$(nproc) / 2"|bc)
  rm -rf xmlrpc-c  >>"${OUTTO}" 2>&1
  if [[ -e /root/tmp/libtorrent-${LTORRENT}.tar.gz ]]; then rm -rf libtorrent-${LTORRENT}.tar.gz;fi
  cp $REPOURL/sources/libtorrent-${LTORRENT}.tar.gz .
  tar -xzvf libtorrent-${LTORRENT}.tar.gz >>"${OUTTO}" 2>&1
  cd libtorrent-${LTORRENT}
  ./autogen.sh >>"${OUTTO}" 2>&1
  ./configure --prefix=/usr >>"${OUTTO}" 2>&1
  make -j${MAXCPUS} >>"${OUTTO}" 2>&1
  make install >>"${OUTTO}" 2>&1
}

# rtorrent function (10.1)
function _rtorrent() {
  cd /root/tmp
  MAXCPUS=$(echo "$(nproc) / 2"|bc)
  rm -rf libtorrent-${LTORRENT}* >>"${OUTTO}" 2>&1
  if [[ -e /root/tmp/libtorrent-${LTORRENT}.tar.gz ]]; then rm -rf libtorrent-${LTORRENT}.tar.gz;fi
  cp $REPOURL/sources/rtorrent-${RTVERSION}.tar.gz .
  tar -xzvf rtorrent-${RTVERSION}.tar.gz >>"${OUTTO}" 2>&1
  cd rtorrent-${RTVERSION}
  ./autogen.sh >>"${OUTTO}" 2>&1
  ./configure --prefix=/usr --with-xmlrpc-c >>"${OUTTO}" 2>&1
  make -j${MAXCPUS} >>"${OUTTO}" 2>&1
  make install >>"${OUTTO}" 2>&1
  cd /root/tmp
  ldconfig >>"${OUTTO}" 2>&1
  rm -rf /root/tmp/rtorrent-${RTVERSION}* >>"${OUTTO}" 2>&1
  touch /install/.rtorrent.lock
}

# scgi enable function (13-nixed)
# function _scgi() { ln -s /etc/apache2/mods-available/scgi.load /etc/apache2/mods-enabled/scgi.load >>"${OUTTO}" 2>&1 ; }

# function to install rutorrent (13)
function _rutorrent() {
  mkdir -p /srv/
  cd /srv
  if [[ -d /srv/rutorrent ]]; then rm -rf rutorrent;fi
  cp -R ${REPOURL}/rutorrent .
  sed -i '31i\<script type=\"text/javascript\" src=\"./js/jquery.browser.js\"></script> ' /srv/rutorrent/index.html

cat >/srv/rutorrent/.htaccess<<'EOF'
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
EOF

cat >/srv/rutorrent/home/.htaccess<<'EOF'
RewriteEngine On
RewriteCond %{HTTPS} !=on
RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
EOF
}

# ask for bash or lshell function (14)
# Heads Up: lshell is disabled for the initial user on install as your first user should not be limited in shell.
# Additional created users are automagically added to a limited shell environment.
function _askshell() {
  #echo -ne "${yellow}Set user shell to lshell?${normal} (Default: ${red}N${normal}): "; read responce
  #case $responce in
  #  [yY] | [yY][Ee][Ss] ) theshell="/usr/bin/lshell" ;;
  #  [nN] | [nN][Oo] | "" ) theshell="/bin/bash" ;;
  #  *) theshell="yes" ;;
  #esac
  echo -ne "${bold}${yellow}Add user to /etc/sudoers${normal} [${green}y${normal}]es or [n]o: "; read answer
  case $answer in
    [yY] | [yY][Ee][Ss] | "" ) sudoers="yes" ;;
    [nN] | [nN][Oo] ) sudoers="no" ;;
    *) sudoers="yes" ;;
  esac
}

# adduser function (15)
function _adduser() {
  theshell="/bin/bash";
  echo "${bold}${yellow}Add a Master Account user to sudoers${normal}";
  echo -n "Username: "; read user
  username=$(echo "$user"|sed 's/.*/\L&/')
  useradd "${username}" -m -G www-data -s "${theshell}"
  echo -n "Password: (hit enter to generate a password) "; read password
  if [[ ! -z "${password}" ]]; then
    echo "setting password to ${password}"
    passwd=${password}
    echo "${username}:${passwd}" | chpasswd >>"${OUTTO}" 2>&1
    (echo -n "${username}:${REALM}:" && echo -n "${username}:${REALM}:${passwd}" | md5sum | awk '{print $1}' ) >> "${HTPASSWD}"
  else
    echo "setting password to ${genpass}"
    passwd=${genpass}
    echo "${username}:${passwd}" | chpasswd >>"${OUTTO}" 2>&1
    (echo -n "${username}:${REALM}:" && echo -n "${username}:${REALM}:${passwd}" | md5sum | awk '{print $1}' ) >> "${HTPASSWD}"
  fi
}

# function to enable sudo for www-data function (16)
function _apachesudo() {
  cd /etc
  rm sudoers
  wget -q https://raw.githubusercontent.com/Swizards/QuickBox/master/sources/sudoers
  #if [[ $sudoers == "yes" ]]; then
    awk -v username=${username} '/^root/ && !x {print username    " ALL=(ALL:ALL) NOPASSWD: ALL"; x=1} 1' /etc/sudoers > /tmp/sudoers;mv /tmp/sudoers /etc
    echo -n "${username}" > /etc/apache2/master.txt
  #fi
  cd
}

# function to configure apache (17)
function _apacheconf() {
  if [[ "${rel}" = "16.04" ]]; then
  a2enmod actions >>"${OUTTO}" 2>&1
  a2enmod fastcgi >>"${OUTTO}" 2>&1
  #a2dismod mpm_prefork >>"${OUTTO}" 2>&1
  #a2enmod mpm_worker >>"${OUTTO}" 2>&1
cat >"/etc/php/7.0/fpm/pool.d/${username}.conf"<<EOF
[${username}]
    user = ${username}
    group = ${username}
    listen = /run/php/php7.0-fpm.${username}.sock
    listen.owner = ${username}
    listen.group = ${username}

    pm = dynamic
    pm.max_children = 5
    pm.start_servers = 2
    pm.min_spare_servers = 1
    pm.max_spare_servers = 3
EOF
  fi
cat >/etc/apache2/sites-enabled/aliases-seedbox.conf<<EOF
Alias /rutorrent "/srv/rutorrent"
<Directory "/srv/rutorrent">
  Options Indexes FollowSymLinks MultiViews
  AuthType Digest
  AuthName "rutorrent"
  AuthUserFile '/etc/htpasswd'
  Require valid-user
  AllowOverride None
  Order allow,deny
  allow from all
</Directory>
Alias /${username}.downloads "/home/${username}/torrents/"
<Directory "/home/${username}/torrents/">
  Options Indexes FollowSymLinks MultiViews
  AuthType Digest
  AuthName "rutorrent"
  AuthUserFile '/etc/htpasswd'
  Require valid-user
  AllowOverride None
  Order allow,deny
  allow from all
</Directory>
Alias /${username}.deluge.downloads "/home/${username}/downloads/deluge.files/"
<Directory "/home/${username}/downloads/deluge.files/">
  Options Indexes FollowSymLinks MultiViews
  AllowOverride None
  AuthType Digest
  AuthName "rutorrent"
  AuthUserFile '/etc/htpasswd'
  Require valid-user
  Order allow,deny
  Allow from all
</Directory>
Alias /${username}.console "/home/${username}/.console/"
<Directory "/home/${username}/.console/">
  Options Indexes FollowSymLinks MultiViews
  AuthType Digest
  AuthName "rutorrent"
  AuthUserFile '/etc/htpasswd'
  Require valid-user
  AllowOverride None
  Order allow,deny
  allow from all
</Directory>
EOF
  a2enmod auth_digest >>"${OUTTO}" 2>&1
  a2enmod ssl >>"${OUTTO}" 2>&1
  a2enmod scgi >>"${OUTTO}" 2>&1
  a2enmod rewrite >>"${OUTTO}" 2>&1
  mv /etc/apache2/sites-enabled/000-default.conf /etc/apache2/ >>"${OUTTO}" 2>&1
cat >/etc/apache2/sites-enabled/default-ssl.conf<<EOF
SSLPassPhraseDialog  builtin
SSLSessionCache         shmcb:/var/cache/mod_ssl/scache(512000)
SSLSessionCacheTimeout  300
#SSLMutex default
SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin
SSLCryptoDevice builtin
<VirtualHost *:80>
        DocumentRoot "/srv/rutorrent/home"
        <Directory "/srv/rutorrent/home/">
                Options Indexes FollowSymLinks
                AllowOverride All AuthConfig
                Order allow,deny
                Allow from all
        AuthType Digest
        AuthName "${REALM}"
        AuthUserFile '${HTPASSWD}'
        Require valid-user
        </Directory>
SCGIMount /${username} 127.0.0.1:$PORT
</VirtualHost>
<VirtualHost *:443>
Options +Indexes +MultiViews +FollowSymLinks
SSLEngine on
        DocumentRoot "/srv/rutorrent/home"
        <Directory "/srv/rutorrent/home/">
                Options +Indexes +FollowSymLinks +MultiViews
                AllowOverride All AuthConfig
                Order allow,deny
                Allow from all
        AuthType Digest
        AuthName "${REALM}"
        AuthUserFile '${HTPASSWD}'
        Require valid-user
        </Directory>
        SSLEngine on
        SSLProtocol all -SSLv2
        SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW
        SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
        SetEnvIf User-Agent ".*MSIE.*" \
                 nokeepalive ssl-unclean-shutdown \
                 downgrade-1.0 force-response-1.0
SCGIMount /${username} 127.0.0.1:$PORT
</Virtualhost>
SCGIMount /${username} 127.0.0.1:$PORT
EOF

cat >/etc/apache2/sites-enabled/fileshare.conf<<DOE
<Directory "/srv/rutorrent/home/fileshare">
    Options -Indexes
    AllowOverride All
    Satisfy Any
</Directory>
DOE

if [[ "${rel}" = "16.04" ]]; then
  sed -i.bak -e "s/post_max_size = 8M/post_max_size = 64M/" \
           -e "s/upload_max_filesize = 2M/upload_max_filesize = 92M/" \
           -e "s/expose_php = On/expose_php = Off/" \
           -e "s/128M/768M/" \
           -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" \
           -e "s/;opcache.enable=0/opcache.enable=1/" \
           -e "s/;opcache.memory_consumption=64/opcache.memory_consumption=128/" \
           -e "s/;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=4000/" \
           -e "s/;opcache.revalidate_freq=2/opcache.revalidate_freq=240/" /etc/php/7.0/fpm/php.ini
# ensure opcache module is activated
phpenmod -v 7.0 opcache >>"${OUTTO}" 2>&1
#a2enmod proxy_fcgi >>"${OUTTO}" 2>&1
  sed -i 's/memory_limit = 128M/memory_limit = 768M/g' /etc/php/7.0/apache2/php.ini
else
  sed -i 's/memory_limit = 128M/memory_limit = 768M/g' /etc/php5/apache2/php.ini
fi
}

# install deluge question ()
function _askdeluge() {
  echo -n "${bold}${yellow}Would you like to install Deluge?${normal} [${green}y${normal}]es or [n]o: "; read responce
  case $responce in
    [yY] | [yY][Ee][Ss] | "" ) deluge=yes ;;
    [nN] | [nN][Oo] ) deluge=no ;;
    *) deluge=yes ;;
  esac
}

# build deluge from source ()
function _deluge() {
  DELUGE_VERSION=1.3.12
  cd /root/tmp
  apt-get -y install python python-geoip python-libtorrent python-notify python-pygame python-gtk2 python-gtk2-dev python-twisted python-twisted-web2 python-openssl python-simplejson python-setuptools gettext python-xdg python-chardet librsvg2-dev xdg-utils python-mako >>"${OUTTO}" 2>&1
  sudo kill -9 `sudo ps aux | grep deluge | grep -v grep | awk '{print $2}' | cut -d. -f 1` &> /dev/null
  sudo wget https://github.com/Swizards/QuickBox/raw/experimental/sources/deluge_"${DELUGE_VERSION}".tar.gz &> /dev/null
  mkdir -p /etc/quickbox/sources
  cd /etc/quickbox/sources
  sudo tar xvfz deluge_"${DELUGE_VERSION}".tar.gz &> /dev/null
  sudo rm deluge_"${DELUGE_VERSION}".tar.gz &> /dev/null
  cd deluge_"${DELUGE_VERSION}"
  sudo python setup.py build >>"${OUTTO}" 2>&1
  sudo python setup.py install >>"${OUTTO}" 2>&1
  sudo ldconfig >>"${OUTTO}" 2>&1
}

function _delugecore() {
  home="/home/${username}"
  #mkdir -p /home/${username}/{.config/deluge/{icons,plugins,ssl,state},deluge.torrents,downloads/deluge.files,dwatch} >>"${OUTTO}" 2>&1
cat >"${home}"/.config/deluge/core.conf<<DL
{
  "file": 1,
  "format": 1
}{
  "info_sent": 0.0,
  "lsd": true,
  "max_download_speed": -1.0,
  "send_info": false,
  "natpmp": true,
  "move_completed_path": "$home/downloads/deluge.files/",
  "peer_tos": "0x00",
  "enc_in_policy": 1,
  "queue_new_to_top": false,
  "ignore_limits_on_local_network": true,
  "rate_limit_ip_overhead": true,
  "daemon_port": $DPORT,
  "torrentfiles_location": "$home/deluge.torrents/",
  "max_active_limit": 8,
  "geoip_db_location": "/usr/share/GeoIP/GeoIP.dat",
  "upnp": true,
  "utpex": true,
  "max_active_downloading": 3,
  "max_active_seeding": 5,
  "allow_remote": true,
  "outgoing_ports": [
    0,
    0
  ],
  "enabled_plugins": [],
  "max_half_open_connections": 50,
  "download_location": "$home/downloads/deluge.files/",
  "compact_allocation": false,
  "max_upload_speed": -1.0,
  "plugins_location": "$home/.config/deluge/plugins",
  "max_connections_global": 200,
  "enc_prefer_rc4": true,
  "cache_expiry": 60,
  "dht": true,
  "stop_seed_at_ratio": false,
  "stop_seed_ratio": 2.0,
  "max_download_speed_per_torrent": -1,
  "prioritize_first_last_pieces": false,
  "max_upload_speed_per_torrent": -1,
  "auto_managed": true,
  "enc_level": 2,
  "copy_torrent_file": false,
  "max_connections_per_second": 20,
  "listen_ports": [
    $PORT,
    $PORTEND
  ],
  "max_connections_per_torrent": -1,
  "del_copy_torrent_file": false,
  "move_completed": false,
  "autoadd_enable": false,
  "proxies": {
    "peer": {
      "username": "",
      "password": "",
      "hostname": "",
      "type": 0,
      "port": 8080
    },
    "web_seed": {
      "username": "",
      "password": "",
      "hostname": "",
      "type": 0,
      "port": 8080
    },
    "tracker": {
      "username": "",
      "password": "",
      "hostname": "",
      "type": 0,
      "port": 8080
    },
    "dht": {
      "username": "",
      "password": "",
      "hostname": "",
      "type": 0,
      "port": 8080
    }
  },
  "dont_count_slow_torrents": false,
  "add_paused": false,
  "random_outgoing_ports": true,
  "max_upload_slots_per_torrent": -1,
  "new_release_check": true,
  "enc_out_policy": 1,
  "seed_time_ratio_limit": 7.0,
  "remove_seed_at_ratio": false,
  "autoadd_location": "$home/dwatch",
  "max_upload_slots_global": 4,
  "seed_time_limit": 180,
  "cache_size": 512,
  "share_ratio_limit": 2.0,
  "random_port": true,
  "listen_interface": ""
}
DL
}

function _delugeconf() {
  DELUGESALT=$(perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 32)
  SHAPASSWD=$(deluge.Userpass.py ${password} ${delugegenpass})
  home="/home/${username}"
cat >"${home}"/.config/deluge/web.conf<<DWC
{
  "file": 1,
  "format": 1
}{
  "sidebar_show_zero": false,
  "show_session_speed": false,
  "pwd_sha1": "$SHAPASSWD",
  "show_sidebar": true,
  "enabled_plugins": [],
  "base": "/",
  "first_login": false,
  "theme": "gray",
  "pkey": "ssl/daemon.pkey",
  "cert": "ssl/daemon.cert",
  "session_timeout": 3600,
  "https": false,
  "default_daemon": "",
  "sidebar_multiple_filters": true,
  "pwd_salt": "$DELUGESALT",
  "port": $WEBPORT
}
DWC
  echo "You may access Deluge at http://${ip}:$WEBPORT" >>/root/"${username}".info
}

# function to configure first user config (18)
function _rconf() {
cat >"/home/${username}/.rtorrent.rc"<<EOF
# -- START HERE --
min_peers = 1
max_peers = 100
min_peers_seed = -1
max_peers_seed = -1
max_uploads = 100
download_rate = 0
upload_rate = 0
directory = /home/${username}/torrents/
session = /home/${username}/.sessions/
schedule = watch_directory,5,5,load_start=/home/${username}/rwatch/*.torrent
schedule = filter_active,5,5,"view_filter = active,d.get_up_rate="
view_add = alert
view_sort_new = alert,less=d.get_message=
schedule = filter_alert,30,30,"view_filter = alert,d.get_message=; view_sort = alert"
port_range = $PORT-$PORTEND
use_udp_trackers = yes
encryption = allow_incoming,try_outgoing,enable_retry
peer_exchange = no
port_random = yes
scgi_port = localhost:$PORT
execute_nothrow=chmod,777,/home/${username}/.config/rpc.socket
execute_nothrow=chmod,777,/home/${username}/.sessions/
check_hash = no
# -- END HERE --
EOF
}

# function to install rutorrent plugins (19)
function _plugins() {
  mkdir -p /etc/quickbox/rutorrent/plugins/
  mv "${REPOURL}/plugins/" /etc/quickbox/rutorrent/
  PLUGINVAULT="/etc/quickbox/rutorrent/plugins/"
  mkdir -p "${rutorrent}plugins"; cd "${rutorrent}plugins"
  if [[ ${primaryroot} == "root" ]]; then
    LIST="_getdir _noty _noty2 _task autodl-irssi autotools check_port chunks cookies cpuload create data datadir diskspace edit erasedata extratio extsearch feeds filedrop filemanager fileshare fileupload geoip history httprpc loginmgr logoff lookat mediainfo mobile pausewebui ratio ratiocolor retrackers rpc rss rssurlrewrite rutracker_check scheduler screenshots seedingtime show_peers_like_wtorrent source stream theme throttle tracklabels trafic unpack xmpp"
  else
    LIST="_getdir _noty _noty2 _task autodl-irssi autotools check_port chunks cookies cpuload create data datadir diskspaceh edit erasedata extratio extsearch feeds filedrop filemanager fileshare fileupload geoip history httprpc loginmgr logoff lookat mediainfo mobile pausewebui ratio ratiocolor retrackers rpc rss rssurlrewrite rutracker_check scheduler screenshots seedingtime show_peers_like_wtorrent source stream theme throttle tracklabels trafic unpack xmpp"
  fi
  for i in $LIST; do
  cp -R "${PLUGINVAULT}$i" .
  done

cat >/srv/rutorrent/home/fileshare/.htaccess<<EOF
Satisfy Any
EOF

  cp /srv/rutorrent/home/fileshare/.htaccess /srv/rutorrent/plugins/fileshare/
  cd /srv/rutorrent/home/fileshare/
  rm -rf share.php
  ln -s ../../plugins/fileshare/share.php

cat >/srv/rutorrent/plugins/fileshare/conf.php<<'EOF'
<?php
$limits['duration'] = 24;   // maximum duration hours
$limits['links'] = 0;   //maximum sharing links per user
$downloadpath = $_SERVER['HTTP_HOST'] . '/fileshare/share.php';
?>
EOF

  sed -i 's/homeDirectory/topDirectory/g' /srv/rutorrent/plugins/filemanager/flm.class.php
  sed -i 's/homeDirectory/topDirectory/g' /srv/rutorrent/plugins/filemanager/settings.js.php
  sed -i 's/showhidden: true,/showhidden: false,/g' "${rutorrent}plugins/filemanager/init.js"
  chown -R www-data.www-data "${rutorrent}"
  cd /srv/rutorrent/plugins/theme/themes/

  git clone https://github.com/Swizards/club-Swizards.git club-Swizards >>"${OUTTO}" 2>&1
  chown -R www-data: club-Swizards
  #cp /etc/quickbox/rutorrent/plugins/rutorrent-quickbox-dark.zip .
  #unzip rutorrent-quickbox-dark.zip >>"${OUTTO}" 2>&1
  #rm -rf rutorrent-quickbox-dark.zip
  cd /srv/rutorrent/plugins
  perl -pi -e "s/\$defaultTheme \= \"\"\;/\$defaultTheme \= \"club-Swizards\"\;/g" /srv/rutorrent/plugins/theme/conf.php
  rm -rf /srv/rutorrent/plugins/tracklabels/labels/nlb.png

  # Needed for fileupload
  wget http://ftp.nl.debian.org/debian/pool/main/p/plowshare/plowshare4_2.1.3-1_all.deb -O plowshare4.deb >>"${OUTTO}" 2>&1
  wget http://ftp.nl.debian.org/debian/pool/main/p/plowshare/plowshare_2.1.3-1_all.deb -O plowshare.deb >>"${OUTTO}" 2>&1
  apt-get -y install plowshare >>"${OUTTO}" 2>&1
  dpkg -i plowshare*.deb >>"${OUTTO}" 2>&1
  rm -rf plowshare*.deb >>"${OUTTO}" 2>&1
  cd /root
  mkdir -p /root/bin
  git clone https://github.com/mcrapet/plowshare.git ~/.plowshare-source >>"${OUTTO}" 2>&1
  cd ~/.plowshare-source >>"${OUTTO}" 2>&1
  make install PREFIX=$HOME >>"${OUTTO}" 2>&1
  cd && rm -rf .plowshare-source >>"${OUTTO}" 2>&1
  apt-get -f install >>"${OUTTO}" 2>&1

  mkdir -p /srv/rutorrent/conf/users/"${username}"/plugins/fileupload/
  chmod 775 /srv/rutorrent/plugins/fileupload/scripts/upload
  cp /srv/rutorrent/plugins/fileupload/conf.php /srv/rutorrent/conf/users/"${username}"/plugins/fileupload/conf.php
  chown -R www-data: /srv/rutorrent/conf/users/"${username}"

  # Set proper permissions to filemanager so it may execute commands
  find /srv/rutorrent/plugins/filemanager/scripts -type f -exec chmod 755 {} \;
}

# function autodl to install autodl irssi scripts (20)
function _autodl() {
  mkdir -p "/home/${username}/.irssi/scripts/autorun/" >>"${OUTTO}" 2>&1
  cd "/home/${username}/.irssi/scripts/"
  wget -qO autodl-irssi.zip https://github.com/autodl-community/autodl-irssi/releases/download/community-v1.62/autodl-irssi-community-v1.62.zip
  unzip -o autodl-irssi.zip >>"${OUTTO}" 2>&1
  rm autodl-irssi.zip
  cp autodl-irssi.pl autorun/
  mkdir -p "/home/${username}/.autodl" >>"${OUTTO}" 2>&1
  touch "/home/${username}/.autodl/autodl.cfg"
  touch /install/.autodlirssi.lock

cat >"/home/${username}/.autodl/autodl2.cfg"<<ADC
[options]
gui-server-port = ${IRSSI_PORT}
gui-server-password = ${IRSSI_PASS}
ADC

  chown -R "${username}.${username}" "/home/${username}/.irssi/"
  chown -R "${username}.${username}" "/home/${username}"
}

function _plugincommands() {
  mkdir -p /etc/quickbox/commands/rutorrent/plugins
  mv "${PLUGINURL}" /etc/quickbox/commands/rutorrent/
  PLUGINCOMMANDS="/etc/quickbox/commands/rutorrent/plugins/"; cd "/usr/local/bin"
  if [[ ${primaryroot} == "root" ]]; then
    LIST="installplugin-getdir removeplugin-getdir installplugin-task removeplugin-task installplugin-autodl removeplugin-autodl installplugin-autotools removeplugin-autotools installplugin-checkport removeplugin-checkport installplugin-chunks removeplugin-chunks installplugin-cookies removeplugin-cookies installplugin-cpuload removeplugin-cpuload installplugin-create removeplugin-create installplugin-data removeplugin-data installplugin-datadir removeplugin-datadir installplugin-diskspace removeplugin-diskspace installplugin-edit removeplugin-edit installplugin-erasedata removeplugin-erasedata installplugin-extratio removeplugin-extratio installplugin-extsearch removeplugin-extsearch installplugin-feeds removeplugin-feeds installplugin-filedrop removeplugin-filedrop installplugin-filemanager removeplugin-filemanager installplugin-fileshare removeplugin-fileshare installplugin-fileupload removeplugin-fileupload installplugin-history removeplugin-history installplugin-httprpc removeplugin-httprpc installplugin-ipad removeplugin-ipad installplugin-loginmgr removeplugin-loginmgr installplugin-logoff removeplugin-logoff installplugin-lookat removeplugin-lookat installplugin-mediainfo removeplugin-mediainfo installplugin-mobile removeplugin-mobile installplugin-noty removeplugin-noty installplugin-pausewebui removeplugin-pausewebui installplugin-ratio removeplugin-ratio installplugin-ratiocolor removeplugin-ratiocolor installplugin-retrackers removeplugin-retrackers installplugin-rpc removeplugin-rpc installplugin-rss removeplugin-rss installplugin-rssurlrewrite removeplugin-rssurlrewrite installplugin-rutracker_check removeplugin-rutracker_check installplugin-scheduler removeplugin-scheduler installplugin-screenshots removeplugin-screenshots installplugin-seedingtime removeplugin-seedingtime installplugin-show_peers_like_wtorrent removeplugin-show_peers_like_wtorrent installplugin-source removeplugin-source installplugin-stream removeplugin-stream installplugin-theme removeplugin-theme installplugin-throttle removeplugin-throttle installplugin-tracklabels removeplugin-tracklabels installplugin-trafic removeplugin-trafic installplugin-unpack removeplugin-unpack installplugin-xmpp removeplugin-xmpp"
  else
    LIST="installplugin-getdir removeplugin-getdir installplugin-task removeplugin-task installplugin-autodl removeplugin-autodl installplugin-autotools removeplugin-autotools installplugin-checkport removeplugin-checkport installplugin-chunks removeplugin-chunks installplugin-cookies removeplugin-cookies installplugin-cpuload removeplugin-cpuload installplugin-create removeplugin-create installplugin-data removeplugin-data installplugin-datadir removeplugin-datadir installplugin-diskspaceh removeplugin-diskspaceh installplugin-edit removeplugin-edit installplugin-erasedata removeplugin-erasedata installplugin-extratio removeplugin-extratio installplugin-extsearch removeplugin-extsearch installplugin-feeds removeplugin-feeds installplugin-filedrop removeplugin-filedrop installplugin-filemanager removeplugin-filemanager installplugin-fileshare removeplugin-fileshare installplugin-fileupload removeplugin-fileupload installplugin-history removeplugin-history installplugin-httprpc removeplugin-httprpc installplugin-ipad removeplugin-ipad installplugin-loginmgr removeplugin-loginmgr installplugin-logoff removeplugin-logoff installplugin-lookat removeplugin-lookat installplugin-mediainfo removeplugin-mediainfo installplugin-mobile removeplugin-mobile installplugin-noty removeplugin-noty installplugin-pausewebui removeplugin-pausewebui installplugin-ratio removeplugin-ratio installplugin-ratiocolor removeplugin-ratiocolor installplugin-retrackers removeplugin-retrackers installplugin-rpc removeplugin-rpc installplugin-rss removeplugin-rss installplugin-rssurlrewrite removeplugin-rssurlrewrite installplugin-rutracker_check removeplugin-rutracker_check installplugin-scheduler removeplugin-scheduler installplugin-screenshots removeplugin-screenshots installplugin-seedingtime removeplugin-seedingtime installplugin-show_peers_like_wtorrent removeplugin-show_peers_like_wtorrent installplugin-source removeplugin-source installplugin-stream removeplugin-stream installplugin-theme removeplugin-theme installplugin-throttle removeplugin-throttle installplugin-tracklabels removeplugin-tracklabels installplugin-trafic removeplugin-trafic installplugin-unpack removeplugin-unpack installplugin-xmpp removeplugin-xmpp"
  fi
  for i in $LIST; do
  cp -R "${PLUGINCOMMANDS}$i" .
  dos2unix installplugin* removeplugin* >>"${OUTTO}" 2>&1;
  chmod +x installplugin* removeplugin* >>"${OUTTO}" 2>&1;
  done
}

function _additionalsyscommands() {
    cd /usr/local/bin
    wget -q -O /usr/local/bin/clean_mem https://raw.githubusercontent.com/Swizards/QuickBox/master/commands/clean_mem
    wget -q -O /usr/local/bin/showspace https://raw.githubusercontent.com/Swizards/QuickBox/master/commands/showspace
    wget -q -O /usr/local/bin/setdisk https://raw.githubusercontent.com/Swizards/QuickBox/development/commands/setdisk
    wget -q -O /usr/local/bin/deluge.changeUserpass.py https://raw.githubusercontent.com/Swizards/QuickBox/experimental/commands/deluge.changeUserpass.py
    wget -q -O /usr/local/bin/deluge.Userpass.py https://raw.githubusercontent.com/Swizards/QuickBox/experimental/commands/deluge.Userpass.py
    dos2unix clean_mem showspace setdisk deluge.Userpass.py deluge.changeUserpass.py >>"${OUTTO}" 2>&1;
    chmod +x clean_mem showspace setdisk deluge.Userpass.py deluge.changeUserpass.py >>"${OUTTO}" 2>&1;
    cd
}

# function to make dirs for first user (21)
function _makedirs() {
  #mkdir /home/"${username}"/{torrents,.sessions,watch} >>"${OUTTO}" 2>&1
  cp -r /etc/skel/* /home/"${username}"
  chown -r "${username}".www-data /home/"${username}" >>"${OUTTO}" 2>&1 #/{torrents,.sessions,watch,.rtorrent.rc} >>"${OUTTO}" 2>&1
  usermod -a -G www-data "${username}" >>"${OUTTO}" 2>&1
  usermod -a -G "${username}" www-data >>"${OUTTO}" 2>&1
}

# function to make crontab .statup file (22)
function _cronfile() {
cat >"/home/${username}/.startup"<<'EOF'
#!/bin/bash
export USER=`id -un`
IRSSI_CLIENT=yes
RTORRENT_CLIENT=yes
WIPEDEAD=yes
ADDRESS=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

if [ "$WIPEDEAD" == "yes" ]; then
  screen -wipe >/dev/null 2>&1;
fi

if [ "$IRSSI_CLIENT" == "yes" ]; then
  (screen -ls|grep irssi >/dev/null || (screen -S irssi -d -t irssi -m irssi -h "${ADDRESS}" && false))
fi

if [ "$RTORRENT_CLIENT" == "yes" ]; then
  (screen -ls|grep rtorrent >/dev/null || (screen -fa -dmS rtorrent rtorrent && false))
fi

EOF

}

# function to set permissions on first user (23)
function _perms() {
  chown -R ${username}.${username} /home/${username}/ >>"${OUTTO}" 2>&1
  chown ${username}.${username} /home/${username}/.startup
  sudo -u ${username} chmod 755 /home/${username}/ >>"${OUTTO}" 2>&1
  chmod +x /etc/cron.daily/denypublic >/dev/null 2>&1
  chmod 777 /home/${username}/.sessions >/dev/null 2>&1
  chown ${username}.${username} /home/${username}/.startup >/dev/null 2>&1
  chmod +x /home/${username}/.startup >/dev/null 2>&1
}

# function to configure first user config.php (24)
function _ruconf() {
  mkdir -p ${rutorrent}conf/users/${username}/

cat >"${rutorrent}conf/users/${username}/config.php"<<EOF
<?php
  @define('HTTP_USER_AGENT', 'Mozilla/5.0 (Windows NT 6.0; WOW64; rv:12.0) Gecko/20100101 Firefox/12.0', true);
  @define('HTTP_TIME_OUT', 30, true);
  @define('HTTP_USE_GZIP', true, true);
  \$httpIP = null;
  @define('RPC_TIME_OUT', 5, true);
  @define('LOG_RPC_CALLS', false, true);
  @define('LOG_RPC_FAULTS', true, true);
  @define('PHP_USE_GZIP', false, true);
  @define('PHP_GZIP_LEVEL', 2, true);
  \$schedule_rand = 10;
  \$do_diagnostic = true;
  \$log_file = '/tmp/errors.log';
  \$saveUploadedTorrents = true;
  \$overwriteUploadedTorrents = false;
  \$topDirectory = '/home/${username}/';
  \$forbidUserSettings = false;
  \$scgi_port = $PORT;
  \$scgi_host = "localhost";
  \$XMLRPCMountPoint = "/RPC2";
  \$pathToExternals = array("php" => '',"curl" => '',"gzip" => '',"id" => '',"stat" => '',);
  \$localhosts = array("127.0.0.1", "localhost",);
  \$profilePath = '../share';
  \$profileMask = 0777;
  \$autodlPort = ${IRSSI_PORT};
  \$autodlPassword = "${IRSSI_PASS}";
  \$diskuser = "";
  \$quotaUser = "";
EOF

  chown -R www-data.www-data "${rutorrent}conf/users/" >>"${OUTTO}" 2>&1
  if [[ ${primaryroot} == "root" ]]; then
    sed -i "/diskuser/c\$diskuser = \"\/\";" /srv/rutorrent/conf/users/${username}/config.php
  else
    sed -i "/diskuser/c\$diskuser = \"\/home\";" /srv/rutorrent/conf/users/${username}/config.php
  fi
  sed -i "/quotaUser/c\$quotaUser = \"${username}\";" /srv/rutorrent/conf/users/${username}/config.php
}

# create reload script (25)
function _reloadscript() {
cat >/usr/bin/reload<<'EOF'
#!/bin/bash
export USER=$(id -un)
pkill -u $USER irssi >/dev/null 2>&1
pkill -u $USER rtorrent >/dev/null 2>&1
killall -u $USER main >/dev/null 2>&1
rm -rf ~/.sessions/rtorrent.lock
EOF
chmod +x /usr/bin/reload
}

# seedbox boot for first user (26)
function _boot() {
        command1="*/1 * * * * /home/${username}/.startup"
        cat <(fgrep -iv "${command1}" <(sh -c 'sudo -u ${username} crontab -l' >/dev/null 2>&1)) <(echo "${command1}") | sudo -u ${username} crontab -
}

# function to install pure-ftpd (27)
function _installftpd() {
  apt purge -q -y vsftpd pure-ftpd >>"${OUTTO}" 2>&1
  apt install -q -y vsftpd >>"${OUTTO}" 2>&1
}

# function to configure pure-ftpd (28)
function _ftpdconfig() {
cat >/root/.openssl.cnf <<EOF
[ req ]
prompt = no
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
C = US
ST = Some State
L = LOCALLY
O = SELF
OU = SELF
CN = SELF
emailAddress = dont@think.so
EOF

  openssl req -config /root/.openssl.cnf -x509 -nodes -days 365 -newkey rsa:1024 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem >/dev/null 2>&1

cat >/etc/vsftpd.conf<<'VSD'
listen=YES
anonymous_enable=NO
guest_enable=NO
dirmessage_enable=YES
dirlist_enable=YES
download_enable=YES
secure_chroot_dir=/var/run/vsftpd/empty
chroot_local_user=YES
chroot_list_file=/etc/vsftpd.chroot_list
passwd_chroot_enable=YES
allow_writeable_chroot=YES
pam_service_name=vsftpd
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=NO
force_local_logins_ssl=NO
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_request_cert=YES
ssl_ciphers=HIGH
rsa_cert_file=/etc/ssl/private/vsftpd.pem
local_enable=YES
write_enable=YES
local_umask=022
max_per_ip=0
pasv_enable=YES
port_enable=YES
pasv_promiscuous=NO
port_promiscuous=NO
pasv_min_port=0
pasv_max_port=0
listen_port=5757
pasv_promiscuous=YES
port_promiscuous=YES
seccomp_sandbox=no
VSD

  echo "" > /etc/vsftpd.chroot_list
}

function _packagecommands() {
  mkdir -p /etc/quickbox/commands/system/packages
  mv "${PACKAGEURL}" /etc/quickbox/commands/system/
  PACKAGECOMMANDS="/etc/quickbox/commands/system/packages/"; cd "/usr/local/bin"
  LIST="installpackage-plex removepackage-plex installpackage-btsync removepackage-btsync installpackage-csf removepackage-csf installpackage-sickrage removepackage-sickrage installpackage-rapidleech removepackage-rapidleech"
  for i in $LIST; do
  #echo -ne "Setting Up and Initializing Plugin Command: ${green}${i}${normal} "
  cp -R "${PACKAGECOMMANDS}$i" .
  dos2unix installpackage* >>"${OUTTO}" 2>&1; dos2unix removepackage* >>"${OUTTO}" 2>&1;
  chmod +x installpackage* >>"${OUTTO}" 2>&1; chmod +x removepackage* >>"${OUTTO}" 2>&1;
  done
}

# function to create ssl cert for pure-ftpd (31)
function _pureftpcert() {
  /bin/true
}

# The following function makes necessary changes to Network and TZ settings needed for
# the proper functionality of the QuickBox Dashboard.
function _quickstats() {
  # Dynamically adjust to use the servers active network adapter
  sed -i "s/eth0/$IFACE/g" /srv/rutorrent/home/widgets/stat.php
  sed -i "s/eth0/$IFACE/g" /srv/rutorrent/home/widgets/data.php
  sed -i "s/eth0/$IFACE/g" /srv/rutorrent/home/widgets/config.php
  sed -i -e "s/eth0/$IFACE/g" \
         -e "s/qb-version/$QBVERSION/g" /srv/rutorrent/home/inc/config.php
  # Use server timezone
  cd /usr/share/zoneinfo
  find * -type f -exec sh -c "diff -q /etc/localtime '{}' > /dev/null && echo {}" \; > ~/tz.txt
  cd ~
  echo "  date_default_timezone_set('$(cat tz.txt)');" >> /srv/rutorrent/home/widgets/config.php
  echo "" >> /srv/rutorrent/home/widgets/config.php
  echo "?>" >> /srv/rutorrent/home/widgets/config.php
  if [[ ${primaryroot} == "home" ]]; then
    cd /srv/rutorrent/home/widgets && rm disk_data.php && { curl -O -s https://raw.githubusercontent.com/Swizards/QuickBox/master/rutorrent/home/widgets/disk_datah.php; }
    mv disk_datah.php disk_data.php
    chown -R www-data:www-data /srv/rutorrent/home/widgets
  else
    rm /srv/rutorrent/home/widgets/disk_datah.php
  fi
}

function _quickconsole() {
  CONSOLEIP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

  sed -i -e "s/console-username/${username}/g" \
         -e "s/console-password/${password}/g" /home/${username}/.console/index.php
}

# function to show finished data (32)
function _finished() {
  ip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
  echo
  echo
  echo -e " ${black}${on_green}    [quickbox] Seddbox & GUI Installation Completed    ${normal} "
  echo -e "        ${standout}    INSTALLATION COMPLETED in ${FIN}/min    ${normal}             "
  echo;echo
  echo "  Valid Commands:  "
  echo '  -------------------'
  echo
  echo -e " ${green}createSeedboxUser${normal} - creates a shelled seedbox user"
  echo -e " ${green}deleteSeedboxUser${normal} - deletes a created seedbox user and their directories"
  echo -e " ${green}changeUserpass${normal} - change users SSH/FTP/ruTorrent password"
  echo -e " ${green}setdisk${normal} - set your disk quota for any given user"
  echo -e " ${green}showspace${normal} - shows the amount of space used by all users on the server"
  echo -e " ${green}reload${normal} - restarts your seedbox services, i.e; rtorrent & irssi"
  echo -e " ${green}upgradeBTSync${normal} - upgrades btsync when new version is available"
  echo -e " ${green}upgradePlex${normal} - upgrades Plex when new version is available"
  echo;echo;echo
  echo '################################################################################################'
  echo "#   Seedbox can be found at https://${username}:${passwd}@${ip} "
  echo "#   ${cyan}(Also works for FTP:5757/SSH:4747)${normal}"
  echo "#   If you need to restart rtorrent/irssi, you can type 'reload'"
  echo "#   https://${username}:${passwd}@${ip} (Also works for FTP:5757/SSH:4747)" > ${username}.info
  if [[ "${rel}" = "16.04" ]]; then
    echo "#   Reloading: ${green}sshd${normal}, ${green}apache${normal}, ${green}memcached${normal}, ${green}php7.0${normal}, ${green}vsftpd${normal}, ${green}fail2ban${normal} and ${green}quota${normal}"
  else
    echo "#   Reloading: ${green}sshd${normal}, ${green}apache${normal}, ${green}vsftpd${normal}, ${green}fail2ban${normal} and ${green}quota${normal}"
  fi
  echo '################################################################################################'
  echo

cat >/root/information.info<<EOF
  Seedbox can be found at https://${username}:${passwd}@${ip} (Also works for FTP:5757/SSH:4747)
  If you need to restart rtorrent/irssi, you can type 'reload'
  https://${username}:${passwd}@${ip} (Also works for FTP:5757/SSH:4747)
EOF

  rm -rf "$0" >>"${OUTTO}" 2>&1
  service quota stop >>"${OUTTO}" 2>&1
  quotaoff -a >>"${OUTTO}" 2>&1
  quotacheck -auMF vfsv1 >>"${OUTTO}" 2>&1
  quotaon -a >>"${OUTTO}" 2>&1
  service quota start >>"${OUTTO}" 2>&1
  service apache2 restart >>"${OUTTO}" 2>&1
  service php7.0-fpm restart >>"${OUTTO}" 2>&1
    for i in ssh apache2 php7.0-fpm vsftpd fail2ban quota memcached cron; do
      service $i restart >>"${OUTTO}" 2>&1
      systemctl enable $i >>"${OUTTO}" 2>&1
    done
  rm -rf /root/tmp/
  echo -ne "  Do you wish to reboot (recommended!): (Default ${green}Y${normal})"; read reboot
  case $reboot in
    [yY] | [yY][Ee][Ss] | "") reboot                 ;;
    [nN] | [nN][Oo] ) echo "  ${cyan}Skipping reboot${normal} ... " ;;
  esac
}

clear

spinner() {
    local pid=$1
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${bold}${yellow}%c${normal}]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -ne "${OK}"
}

Reth0=$(ifconfig | grep -m 1 "Link encap" | sed 's/[ \t].*//;/^\(lo\|\)$/d' | awk '{ print $1 '});
IFACE=$(echo -n "${Reth0}");
HOSTNAME1=$(hostname -s);
REPOURL="/root/tmp/QuickBox"
PLUGINURL="/root/tmp/QuickBox/commands/rutorrent/plugins/"
PACKAGEURL="/root/tmp/QuickBox/commands/system/packages/"
QBVERSION="2.2.2"
PORT=$(shuf -i 2000-61000 -n 1)
PORTEND=$((${PORT} + 1500))
while [[ "$(netstat -ln | grep ':'"$PORT"'' | grep -c 'LISTEN')" -eq "1" ]]; do PORT="$(shuf -i 2000-61000 -n 1)"; done
WEBPORT=$(shuf -i 8115-8145 -n 1)
RPORT=$(shuf -i 2000-61000 -n 1)
DPORT=$(shuf -i 2000-61000 -n 1)
DELUGE_VERSION="1.3.12"
while [[ "$(netstat -ln | grep ':'"$RPORT"'' | grep -c 'LISTEN')" -eq "1" ]]; do RPORT="$(shuf -i 2000-61000 -n 1)"; done
while [[ "$(netstat -ln | grep ':'"$DPORT"'' | grep -c 'LISTEN')" -eq "1" ]]; do DPORT="$(shuf -i 2000-61000 -n 1)"; done
S=$(date +%s)
OK=$(echo -e "[ ${bold}${green}DONE${normal} ]")
genpass=$(_string)
delugegenpass=$(perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 32)
HTPASSWD="/etc/htpasswd"
rutorrent="/srv/rutorrent/"
REALM="rutorrent"
IRSSI_PASS=$(_string)
IRSSI_PORT=$(shuf -i 2000-61000 -n 1)
#ip=$(curl -s http://ipecho.net/plain || curl -s http://ifconfig.me/ip ; echo)
ip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
BTSYNCIP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
export DEBIAN_FRONTEND=noninteractive
cd

# QuickBox STRUCTURE
#_quickboxv
_bashrc
_intro
_checkroot
_logcheck
_askpartition
_askcontinue
_ssdpblock
clear

_repos
_hostname
_askrtorrent
_adduser
_askffmpeg
_denyhosts

echo
echo ""
echo "${bold}${magenta}QuickBox will now install, this may take between${normal}"
echo "${bold}${magenta}10 and 30 minutes depending on your systems specs${normal}"
echo ""
echo -n "Updating system ... ";_updates & spinner $!;echo
echo -n "Installing all needed dependencies ... ";_depends & spinner $!;echo
_additionalsyscommands
echo -n "Building required user directories ... ";_skel & spinner $!;echo
if [[ ${ffmpeg} == "yes" ]]; then
    echo -n "Building ffmpeg from source for screenshots ... ";_ffmpeg & spinner $!;echo
fi
_apachesudo
echo -n "Installing xmlrpc-c-${green}1.33.12${normal} ... ";_xmlrpc & spinner $!;echo
echo -n "Installing libtorrent-${green}$LTORRENT${normal} ... ";_libtorrent & spinner $!;echo
echo -n "Installing rtorrent-${green}$RTVERSION${normal} ... ";_rtorrent & spinner $!;echo
echo -n "Installing rutorrent into /srv ... ";_rutorrent & spinner $!;echo
echo -n "Setting up seedbox.conf for apache ... ";_apacheconf & spinner $!;echo
echo -n "Installing .rtorrent.rc for ${username} ... ";_rconf & spinner $!;echo
echo -n "Installing rutorrent plugins ... ";_plugins & spinner $!;echo
echo -n "Installing autodl-irssi ... ";_autodl & spinner $!;echo;_plugincommands
echo -n "Making ${username} directory structure ... ";_makedirs & spinner $!;echo
echo -n "Writing ${username} system crontab script ... ";_cronfile & spinner $!;echo
echo -n "Writing ${username} rutorrent config.php file ... ";_ruconf & spinner $!;echo
echo -n "Writing seedbox reload script ... ";_reloadscript & spinner $!;echo
echo -n "Installing VSFTPd ... ";_installftpd & spinner $!;echo
echo -n "Setting up VSFTPd ... ";_ftpdconfig & spinner $!;echo
_packagecommands;_quickstats;_quickconsole
echo -n "Setting irssi/rtorrent to start on boot ... ";_boot & spinner $!;echo;
echo -n "Setting permissions on ${username} ... ";_perms & spinner $!;echo;
cd
E=$(date +%s)
DIFF=$(echo "$E" - "$S"|bc)
FIN=$(echo "$DIFF" / 60|bc)
clear
_finished
