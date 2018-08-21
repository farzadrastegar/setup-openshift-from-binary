#!/bin/bash

USAGE="USAGE: ./install-openshift-cli.bash <machine-private-IP> <desired-machine-hostname> <machine-public-IP>"
echo "${USAGE}"
read -p "Press any key to continue..." anykey

# input arguments
machineIP=$1
machineHostname=$2
publicIP=$3

# User-defined functions
verify_with_user() {
   filename=$1
   content=$2

   echo "New ${filename} is:"
   echo "========================"
   echo "${content}"
   echo "========================"
   read -p "Does it look OK?(y/n) " response

   while [[ ( "${response}" != "y" ) && ( "${response}" != "n" ) ]]; do
      read -p "Does it look OK?(y/n) " response
   done

   if [[ ( "${response}" == "n" ) ]]; then
      exit 1
   fi
   echo
}

# Make sure user is root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: this script must be run as root!" 
   exit 1
fi

# Install required packages
yum install -y docker wget vim

# Allow insecure registry
ALLOW_INSECURE_REGISTRY="INSECURE_REGISTRY='--insecure-registry 172.30.0.0/16'"
DOCKER_CONFIG_FILE='/etc/sysconfig/docker'
new_docker_config=$(printf "%s\n%s" "$(cat ${DOCKER_CONFIG_FILE})" "${ALLOW_INSECURE_REGISTRY}")
verify_with_user "${DOCKER_CONFIG_FILE}" "${new_docker_config}"
echo "${new_docker_config}" > ${DOCKER_CONFIG_FILE}
systemctl restart docker

# Set hostname
hostnamectl set-hostname ${machineHostname}
SET_HOSTNAME="${machineIP} ${machineHostname}"
ETC_HOSTS='/etc/hosts'
new_hosts_file=$(printf "%s\n%s" "$(cat ${ETC_HOSTS})" "${SET_HOSTNAME}")
verify_with_user "${ETC_HOSTS}" "${new_hosts_file}"
echo "${new_hosts_file}" > ${ETC_HOSTS}

# Install OpenShift binaries
cd /tmp
mkdir -p bak
mv openshift-origin-server-* bak
wget https://github.com/openshift/origin/releases/download/v3.10.0/openshift-origin-server-v3.10.0-dd10d17-linux-64bit.tar.gz
tar xvzf openshift-origin-server-*.tar.gz
cd openshift-origin-server-*
mv k* o* /usr/local/sbin/

# Create startup script
STARTUP_FILE='/usr/local/bin/start_openshift.sh'
cat << EOF > ${STARTUP_FILE}
#!/bin/bash
cd /opt/openshift/
openshift start --public-master='https://${publicIP}:8443' --master='https://${machineIP}:8443'
EOF

# Create systemd unit file
cat << EOF > /etc/systemd/system/openshift.service
[Unit]
Description=Origin Master Service

[Service]
Type=simple
ExecStart=${STARTUP_FILE}
EOF

# Finalize scripts preparation
OPENSHIFT_DIR='/opt/openshift/'
mkdir -p ${OPENSHIFT_DIR}
chmod u+x ${STARTUP_FILE}
systemctl daemon-reload
systemctl start openshift

# Add a router and registry
cd /root
ROOT_BASHRC='.bashrc'
cat << EOF >> ${ROOT_BASHRC}
export KUBECONFIG=/opt/openshift/openshift.local.config/master/admin.kubeconfig
export CURL_CA_BUNDLE=/opt/openshift/openshift.local.config/master/ca.crt
EOF
source ${ROOT_BASHRC}


