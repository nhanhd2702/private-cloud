#!/bin/bash
#Define variables

cinder_volumes_disk="/dev/sdb"
network_if="ens160"
neutron_ext_if="ens192"
int_vip_address="192.168.100.10"

#Check privilege 
die() {
  echo "ERROR: $1"
  exit 1
}
[ $(whoami) = "root" ] || die "This script must be run as root"
#Update system packages
apt update && sudo apt upgrade -y
apt autoremove -y
#Set date-time
timedatectl set-timezone Asia/Ho_Chi_Minh
#Checking cinders-volume
if vgdisplay | grep -q 'cinder-volumes'; then
  echo "Ch"
else
  echo "Storage not found. Please create cinder-volumes to continue... "
  exit 1;
fi

#Install python libraries & packages
apt install python3-pip python3-dev python3-docker libffi-dev gcc libssl-dev git -y
#Install virtualenv
apt install python3-venv python3-virtualenv -y
#Create virtual environment
if [ ! -d "$HOME/private-cloud" ]; then
python3 -m venv $HOME/private-cloud
fi
# Activate virtual environment
source $HOME/private-cloud/bin/activate
#Upgrade pip tools
pip install -U pip
#Install Ansible
pip install -U 'ansible>=4,<6'
#Install kolla-ansible and its dependencies using pip
pip install "kolla-ansible==15.0.0"
#pip install git+https://opendev.org/openstack/kolla-ansible@stable/zed
#Install Ansible Galaxy requirements
kolla-ansible install-deps
##Prepare configs file for deployment
#Create & tuning ansible
if [[ ! -e /etc/ansible/ansible.cfg ]]; then
    mkdir -p /etc/ansible
    touch /etc/ansible/ansible.cfg
fi
#Tunning ansible
cat << EOF > /etc/ansible/ansible.cfg
[defaults]
host_key_checking=False
pipelining=True
forks=100
EOF
#Create the /etc/kolla directory
[ ! -d "/etc/kolla" ] && mkdir -p /etc/kolla
chown $USER:$USER /etc/kolla
#-	Copy file config template
cp -r $HOME/private-cloud/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp -r $HOME/private-cloud/share/kolla-ansible/ansible/inventory/* /etc/kolla/
#Backup original config files
cd /etc/kolla
cp all-in-one all-in-one.bak
cp globals.yml globals.bak
# Git clone config file template
cd ~
git clone https://github.com/nhanhd2702/private-cloud-templates.git
cp private-cloud-templates/all-in-one-basic/all-in-one /etc/kolla/
cp private-cloud-templates/all-in-one-basic/globals.yml /etc/kolla/
#Update globals.yml 
sed -i 's/$network_if/int_if/' /etc/kolla/globals.yml
sed -i 's/$neutron_ext_if/ext_if/' /etc/kolla/globals.yml
sed -i 's/$int_vip_address/int_vip_ip/' /etc/kolla/globals.yml
#
#Generate setup passwords
kolla-genpwd
## Deployment
byobu
source $HOME/private-cloud/bin/activate
kolla-ansible -i /etc/kolla/all-in-one bootstrap-servers
kolla-ansible -i /etc/kolla/all-in-one prechecks


