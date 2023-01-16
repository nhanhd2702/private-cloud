#!/bin/bash
#Define variables

cinder_volumes_disk="/dev/sdb"
int_if="ens160"
int_vip_address="192.168.100.10"
ext_if="ens192"
# neutron_ext_net_cidr="192.168.200.0/24"
# neutron_ext_net_range_start="192.168.200.100"
# neutron_ext_net_range_end="192.168.200.199"
# neutron_ext_net_gw="192.168.200.1"

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
  echo "Checking cinder-volumes is OK"
else
	echo "Storage not found, Now we will setup cinder-volumes"
mkfs.ext4 $cinder_volumes_disk
pvcreate $cinder_volumes_disk
vgcreate cinder-volumes $cinder_volumes_disk
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
git config --global user.name "nhanhd2702"
git config --global user.email "nhanhd2702@gmail.com"
git config  --global user.passwd "y"
git clone https://github.com/nhanhd2702/private-cloud-templates.git
cd private-cloud-templates
git pull origin base
cd ..
cp private-cloud-templates/aio/all-in-one /etc/kolla/
cp private-cloud-templates/aio/globals.yml /etc/kolla/
#Update globals.yml 
echo "Updating configs"
sed -i "s/int_if/$int_if/" /etc/kolla/globals.yml
sed -i "s/ext_if/$ext_if/" /etc/kolla/globals.yml
sed -i "s/int_vip_ip/$int_vip_address/" /etc/kolla/globals.yml

#
#Generate setup passwords
echo "Generate module passwords"
kolla-genpwd
## Deployment
byobu
source $HOME/private-cloud/bin/activate
kolla-ansible -i /etc/kolla/all-in-one bootstrap-servers
kolla-ansible -i /etc/kolla/all-in-one prechecks
#kolla-ansible -i /etc/kolla/all-in-one deploy
# Post deploy
#kolla-ansible post-deploy
#pip install python-openstackclient python-glanceclient python-neutronclient
# #Create token & resources
# source /etc/kolla/admin-openrc.sh
# openstack token issue
# admin_password=cat /etc/kolla/passwords.yml | grep keystone_admin
# echo "Deployment is complete. Password login is $admin_password"

