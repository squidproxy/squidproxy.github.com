#!/bin/bash
#===========================================================================
# Function Description: Setup a secure web proxy using SSL encryption, Squid Caching Proxy and PAM authentication
# Techlonogy Support : https://github.com/squidproxy
# Author:SIWEI Project
# Version. 1.1
# https://www.stunnel.org/index.html
# Stunnel is a proxy designed to add TLS encryption functionality to existing clients and servers without any changes in the programs' code.
# Its architecture is optimized for security, 
# portability, and scalability (including load-balancing), making it suitable for large deployments.
#===========================================================================

KeyPathrsa=/etc/stunnel/snowleopard-rsa.key
CaPathrsa=/etc/stunnel/snowleopard-rsa-ca.pem

KeyPathecc=/etc/stunnel/snowleopard-ecc.key
CaPathecc=/etc/stunnel/snowleopard-ecc-ca.pem

StunnelRSAcert=/etc/stunnel/stunnel-RSA.pem
StunnelECCcert=/etc/stunnel/stunnel-ECC.pem

StunnelConfPath=/etc/stunnel/stunnel.conf

squidconf1=/etc/squid3/squid.conf
squidconf2=/etc/squid/squid.conf
#stunnel port
PORT=443

function print_info(){
    echo -n -e '\e[1;36m'
    echo -n $1
    echo -e '\e[0m'
}


function coloredEcho(){
    local exp=$1;
    local color=$2;
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput setaf $color;
    echo $exp;
    tput sgr0;
}



check_process() {
#  echo "$ts: checking $1"
  [ "$1" = "" ]  && return 0
  [ `pgrep -n $1` ] && return 1 || return 0
}



function check_stunnel_installed_status() {
#  echo "$ts: checking $1"
  dpkg-query -W -f='${Status} ${Version}\n' stunnel4
  OUT=$?
  if [ $OUT -eq 0 ];then
   coloredEcho "Stunnel4 installed on OS!" green
  else
   coloredEcho "Stunnel does not found,installing now" red
   apt-get install stunnel4 -y
fi
}

function get_squid_port()
{

for SquidconfPath  in $squidconf1 $squidconf2
do

if [ -f $SquidconfPath ]; then
 coloredEcho  "Checking Squid installed " green
 SquidPort=`grep 'http_port' $SquidconfPath | cut -d' ' -f2- | sed -n 1p`
 coloredEcho "Check your Squid running on $SquidPort "  green
  coloredEcho "Squid config path : $SquidconfPath "  green

 else

    if  [ $SquidconfPath == $squidconf1 ];then
    coloredEcho  "Squid3 package no found,skip  ........" green
    continue #skip squid3 conf path

    else
    coloredEcho  "Squid installing ........" green
    read -r -p "${1:-Are you continue? [y/N]} " response

    case "$response" in
            [yY][eE][sS]|[yY])
            wget -N --no-check-certificate https://git.io/vD67J  -O ./SLSrv.sh
            chmod +x SLSrv.sh
            bash SLSrv.sh
            ;;
        *)
            false
            exit 1
            ;;
     esac
fi

fi

done

}


function CheckStunnelStatus()

{

lsof -Pi :$PORT -sTCP:LISTEN -t

if  [ $? -eq 0 ];then

coloredEcho " running," green
service stunnel4 restart

else
coloredEcho  " no running, restarting... " red
service stunnel4 restart
fi

}



function Update_ECC_OR_Conf()
{

for filename  in $KeyPathrsa $CaPathrsa $KeyPathecc $CaPathecc $StunnelRSAcert $StunnelECCcert $StunnelConfPath
do
if [ -f $filename ]; then
coloredEcho  "File '$filename' Exists,will deleted" green
rm $filename
else
coloredEcho  "The File '$filename ' Does Not Exist" red
fi
done

}

function Generate_Stunnel_config()
{

cat << EOF > /etc/stunnel/stunnel.conf

socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

;;;chroot = /var/run/stunnel
pid = /tmp/stunnel.pid

[squid]
# Ensure the .connect. line matches your squid port. Default is 3128
accept = 443
connect = 127.0.0.1:$SquidPort
verify = 4
cert = /etc/stunnel/stunnel-RSA.pem
CAfile = /etc/stunnel/stunnel-RSA.pem

[squid]
# Ensure the .connect. line matches your squid port. Default is 3128
accept = 444
connect = 127.0.0.1:$SquidPort
verify = 4
cert = /etc/stunnel/stunnel-RSA.pem
CAfile = /etc/stunnel/stunnel-RSA.pem

[squid]
accept = 447
connect = 127.0.0.1:$SquidPort
verify = 4
cert = /etc/stunnel/stunnel-ECC.pem
CAfile = /etc/stunnel/stunnel-ECC.pem

[squid]
# Ensure the .connect. line matches your squid port. Default is 3128
accept = 446
connect = 127.0.0.1:$SquidPort
verify = 4
cert = /etc/stunnel/stunnel-ECC.pem
CAfile = /etc/stunnel/stunnel-ECC.pem

EOF

}

function SettingStunnelPort()
{
  echo -e  "input a Stunnel port:\n"
    read text
    PORT=$text 

}

function Generate_ECC_Certificate()
{



Server_add=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
# generate 384bit ca certicate
openssl ecparam -out /etc/stunnel/snowleopard-ecc.key -name  secp256k1 -genkey
openssl req -x509 -new -key /etc/stunnel/snowleopard-ecc.key \
-out /etc/stunnel/snowleopard-ecc-ca.pem -outform PEM -days 3650 \
-subj "/emailAddress=SIWEI/CN=$Server_add/O=SIWEI/OU=SIWEI/C=Sl/ST=cn/L=SIWEI"

#Create the stunnel private key (.pem) and put it in /etc/stunnel.
cat /etc/stunnel/snowleopard-ecc.key /etc/stunnel/snowleopard-ecc-ca.pem >> /etc/stunnel/stunnel-ECC.pem
#Show Algorithm
openssl x509 -in  /etc/stunnel/stunnel-ECC.pem -text -noout
#openssl ecparam -list_curves

}

function Generate_RSA_Certificate()

{

 Server_add=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
openssl genrsa -out /etc/stunnel/snowleopard-rsa.key  $RSA_Key_Size
openssl req -new -x509 -key /etc/stunnel/snowleopard-rsa.key -out /etc/stunnel/snowleopard-rsa-ca.pem -days 1095 \
-subj "/emailAddress=SIWEI/CN=$Server_add/O=SIWEI/OU=SIWEI/C=Sl/ST=cn/L=SIWEI"
cat /etc/stunnel/snowleopard-rsa.key /etc/stunnel/snowleopard-rsa-ca.pem >> /etc/stunnel/stunnel-RSA.pem
#Show Algorithm
openssl x509 -in  /etc/stunnel/stunnel-RSA.pem -text -noout
#openssl ecparam -list_curves
}

function  Choose_Encryption_Algorithm()

{

   echo -e "Choose a Encryption Algorithm:\n 1:rsa\n 2:ECC\n"
    read text
if [ $text -eq 1 ];then

# Set RSA KeySize
        echo -e "Enter RSA KeySize ,Choose:\n 1:2048\n 2:4096\n"
    read text

        if [ $text -eq 1 ];then
        RSA_Key_Size=2048
        fi

        if [ $text -eq 2 ];then
        RSA_Key_Size=4096
        fi
$RSA_Key_Size
    Encryption_Algorithm=RSA+ECC
    echo "You RSA_Key_Size is: $RSA_Key_Size"
    Generate_RSA_Certificate
    Generate_ECC_Certificate
  fi

  
  

}

function check_apache2_intalled_status()
{
	
dpkg-query -W -f='${Status} ${Version}\n' apache2
	
OUT=$?
if [ $OUT -eq 0 ];then
   echo "apache2 installed "
   
   string=`ls /var/www`
if [ -d "/var/www/html" ]; then
 dlpath="/var/www/html"
 rm -rf /var/www/html/stunnel-RSA.pem
 rm -rf /var/www/html/stunnel-ECC.pem
 cp /etc/stunnel/stunnel-RSA.pem $dlpath
 cp /etc/stunnel/stunnel-ECC.pem $dlpath
  
  else
	  
 dlpath="/var/www"
 rm -rf /var/www/stunnel-RSA.pem
 rm -rf /var/www/stunnel-ECC.pem
 cp /etc/stunnel/stunnel-RSA.pem $dlpath
 cp /etc/stunnel/stunnel-ECC.pem $dlpath
	  
fi

fi

}


function Show_StunnelClient_config()
{
coloredEcho "Add blow info for your stunnel client" green

lsof -Pi :443 -sTCP:LISTEN -t &> /dev/null && print_info "Stunnel Service running,port:443"
lsof -Pi :$SquidPort -sTCP:LISTEN -t &> /dev/null && print_info "Squid Service running,port: $SquidPort"
print_info "$Encryption_Algorithm"
print_info "http://$Server_add/stunnel-RSA.pem"
print_info "http://$Server_add/stunnel-ECC.pem"
print_info "$dlpath"

}
check_stunnel_installed_status
Update_ECC_OR_Conf
get_squid_port
#SettingStunnelPort
Generate_Stunnel_config
Choose_Encryption_Algorithm
CheckStunnelStatus
check_apache2_intalled_status
Show_StunnelClient_config
exit 0