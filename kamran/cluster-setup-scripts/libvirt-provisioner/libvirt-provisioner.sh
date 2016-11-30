#!/bin/bash
# This script is used to provision nodes using libvirt.
# You need to be root to run this.

# First, source/load the functions 
source ./functions.sh

echo

# Then, load the cluster.conf file from the parent directory.

if [ -f ../cluster.conf ]; then
  source ../cluster.conf
else
  echolog "cluster.conf was not found in parent directory. Exiting ..."
  exit 1
fi


############### START - Perform Sanity checks on config variables #################
#
#

#if [ ! -f ../hosts ] ; then
if [ checkHostsFile ] ; then
  echolog "Found hosts file."
else
  echolog "You need to provide a hosts file in parent directory of this script, named 'hosts' ."
  echo "The format of hosts file is same as /etc/hosts, with extra columns:"
  echo "IP_ADDRESS	FQDN	Short_Hostname	RAM_in_MB	Disk_in_GB"
  echo
  echo "You can generate a hosts file from your /etc/hosts like so:"
  echo "egrep -v '127.0.0.1|^#'   /etc/hosts  >  hosts"
  echo
  echo "Then add the RAM and Disk columns as described above."
  exit 1
fi


if [ -z "${LIBVIRT_HOST}" ] ||  [ "${LIBVIRT_HOST}" == "localhost" ] ; then
  echolog "LIBVIRT_HOST found empty (or set to localhost). Assuming the local libvirt daemon would be used."
  echolog "Setting LIBVIRT_HOST to qemu:///system"
  LIBVIRT_HOST=qemu:///system
else
  # We have a remote host, so also check if remote user is mentioned
  if [ -z "${LIBVIRT_REMOTE_USER}" ] ; then
    echolog "LIBVIRT_REMOTE_USER found empty. Setting it to user 'root'"
    LIBVIRT_REMOTE_USER=root
  fi
  # Build the connect stringi for remote libvirt connection:
  LIBVIRT_CONNECTION="qemu+ssh://${LIBVIRT_REMOTE_USER}@${LIBVIRT_HOST}/system"
fi
echolog "Setting up libvirt connection string as: ${LIBVIRT_CONNECTION}"


if [ -z "${LIBVIRT_NETWORK_NAME}" ] ; then
  echolog "You need to provide a libvirt network name, with IP address scheme matching IPs of your k8s nodes, pecified in your hosts file."
  echo "You can do it easily using virt-manager GUI interaface. Create a NAT based network in libvirt, and when done, provide it's name as LIBVIRT_NETWORK_NAME in the config file (cluster.conf) ."
  exit 1
else
  if [ "$(virsh net-list --name | grep ${LIBVIRT_NETWORK_NAME} )" == "${LIBVIRT_NETWORK_NAME}" ] &&  [ "$(getLibvirtNetworkState ${LIBVIRT_NETWORK_NAME})" == "active" ] ; then
    echolog "Network ${LIBVIRT_NETWORK_NAME} was found in Libvirt network list, and is in 'active' state."
  else
    echolog "Network ${LIBVIRT_NETWORK_NAME} was not found in Libvirt network list. Or it is not active."
    echolog "You need to provide a libvirt network name, with IP address scheme matching IPs of your k8s nodes, pecified in your hosts file."
    echo "You can do it easily using virt-manager GUI interaface. Create a NAT based network in libvirt, and when done, provide it's name as LIBVIRT_NETWORK_NAME in the config file (cluster.conf) ."
    exit 1
  fi
fi

if  [ -z "${VM_DISK_DIRECTORY}" ] ; then
  echolog "VM_DISK_DIRECTORY found empty. Using the libvirt defaults for vm disks (normally /var/lib/libvirt/images/) . Expecting at least 80 GB free disk space."
else
  if [ ! -d ${VM_DISK_DIRECTORY} ] ; then
    echolog "The location provided to hold VM disks does not exist. $VM_DISK_DIRECTORY."
    echo "Please ensure that the directory exists and is owned by root:libvirt, with permissions 0775. The location needs to have at least 80 GB free disk space."
    exit 1
  else
    echolog "Setting up ${VM_DISK_DIRECTORY} for VM disk image storage... "
  fi
fi


if [ -z "${HTTP_BASE_URL}" ] ; then
  echolog "HTTP_BASE_URL found empty. You need to provide the URL where the provisioner expects the cd contents of the Fedora ISO. Plus a port number in case the port is not 80."
  echo "You also need to have /cdrom and /kickstart being served through this URL."
  echo "Examples of HTTP_URL are:"
  echo "http://localhost/"
  echo "http://localhost:8080/"
  echo "http://server.example.org"
  echo "http://server.example.org:81"
  exit 1
else
  # Lets check if URL is reachable, and that we get a 200 responce from /cdrom and /kickstart.
  # using -k with curl as user may provide a HTTPS url in cluster.conf and that URL may have self signed certs.
  # -k works with both http and https, so using it in all curl commands.
  CURL_CODE=$(curl -k -sL -w "%{http_code}\\n" "${HTTP_BASE_URL}" -o /dev/null)
  if [ ${CURL_CODE} -eq 200 ] ; then
    echolog "HTTP_BASE_URL ( ${HTTP_BASE_URL} ) is accessible! Good. "
    # Lets check if /kickstart and /cdrom are accessible
    CURL_CODE_CDROM=$(curl -k -sL -w "%{http_code}\\n" "${HTTP_BASE_URL}/cdrom/.discinfo" -o /dev/null)
    CURL_CODE_KICKSTART=$(curl -k -sL -w "%{http_code}\\n" "${HTTP_BASE_URL}/kickstart/kickstart-template.ks" -o /dev/null)
    if [ ${CURL_CODE_CDROM} -eq 200 ] && [ ${CURL_CODE_KICKSTART} -eq 200 ] ; then
      echo "/cdrom and /kickstart are also accessible. Hope you have content in there!"
    else
      echolog "The /cdrom and /kickstart locations were not found through HTTP_BASE_URL  ( ${HTTP_BASE_URL}  ) ."
      echo "You need to have these two locations in the document root of your web server."
      exit 1
    fi
  else
    echolog "The URL specified in HTTP_BASE_URL ( ${HTTP_BASE_URL} ) is not reachable!"
    exit 1
  fi
fi


# Need to make sure that kickstart directory exists inside the parent directory. 
# Also it needs to have a kickstart-template.ks file in it as a minimum.

# if [ ! -f ../kickstart/kickstart-template.ks ] ; then
if [ checkKickstart ] ; then
  echolog "kickstart file found in kickstart/kickstart-template.ks in the parent directory."
else
  echolog "kickstart file not found as kickstart/kickstart-template.ks ."
  echolog "You need to have the kickstart directory in the project root directory and also have the kickstart-template.ks file in it."
  exit 1
fi

# checkKickstart

echo
echolog "Sanity checks complete. Proceeding to execute main program ..."
echo
echo "--------------------------------------------------------------------------------------------------"
echo



#
#
############### END - Perform Sanity checks on config variables #################





###############  START - Set system variables #####################
#
#

# Hard coded hosts file (on purpose). Expect/Need a file named 'hosts' in the parent directory.
HOSTS_FILE=../hosts
KICKSTART_DIRECTORY=../kickstart

LIBVIRT_NETWORK_IP=$(getLibvirtNetworkIP $LIBVIRT_NETWORK_NAME)
LIBVIRT_NETWORK_MASK=$(getLibvirtNetworkMask $LIBVIRT_NETWORK_NAME)


# echo "Default Gateway for VMs belonging to this network is: ${LIBVIRT_NETWORK_IP}"
# echo "Network Mask for VMs belonging to this network is: ${LIBVIRT_NETWORK_MASK}"

# Provisioning using kickstart, over the network, requires more RAM than normal.
# So I will use 1280 MB for each VM during provisioning. As soon as node is provisioned, 
# I will use virt-xml to edit the configuration and set the RAM of the node to the 
# amount mentioned in the hosts file.
VM_RAM=1280


#
#
###############  END - Set system variables #####################



###############  START - Main program #####################
#
#

getNodeRAM controller.example.com
getNodeDisk controller1.example.com

THREE_OCTETS=$(getFirstThreeOctectsOfIP ${LIBVIRT_NETWORK_IP})

generateKickstartAll ${THREE_OCTETS} ${LIBVIRT_NETWORK_IP} ${LIBVIRT_NETWORK_MASK}
 
#
#
###############  END - Main program #####################
