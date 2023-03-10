#!/bin/bash

echo "###############################################################"
echo "#                                                             #"
echo "#  You are about to setup a private-cloud multinode system.   #"
echo "#  Press [ENTER] to start the installation process            #"
echo "#  or press [CTRL+C] to exit                                  #"
echo "#                                                             #"
echo "###############################################################"

# Wait for the user to press [ENTER]
read

# Start the installation process
echo "Starting the installation process..."

##Check privilege 
echo "Checking privileges"
die() {
  echo "ERROR: $1"
  exit 1
}

[ $(whoami) = "root" ] || die "This script must be run as root"

# Servers definition
echo "Enter the number of servers: "
read num_servers

for ((i=1; i<=num_servers; i++))
do
    echo "Enter the name of server $i: "
    read server_name
    echo "Enter the IP address of server $i: "
    read server_ip

    # Prompt for the network interface and neutron external interface
    echo "Enter the network interface for server $i: "
    read int_if
    echo "Enter the neutron external interface for server $i: "
    read neutron_ext_if
done

##Update system packages
echo "Updating your system packages"

apt update && sudo apt upgrade -y

apt autoremove -y

#Set date-time
echo "Setting date & time"

timedatectl set-timezone Asia/Ho_Chi_Minh

#Install python libraries & packages

echo "Install python libraries & packages"
apt install python3-pip python3-dev python3-docker libffi-dev gcc libssl-dev git -y

#Install virtualenv
echo "Setting up virtual environment"
apt install python3-venv python3-virtualenv -y

#Create virtual environment

if [ ! -d "$HOME/private-cloud" ]; then
python3 -m venv $HOME/private-cloud

else
    rm -rf "$HOME/private-cloud"
    python3 -m venv $HOME/private-cloud
fi

# Activate virtual environment
echo "Active venv & setting up kolla packages"
source $HOME/private-cloud/bin/activate

#Upgrade pip tools
pip install -U pip

#Install Ansible
pip install -U 'ansible>=4,<6'

#Install kolla-ansible and its dependencies using pip
pip install "kolla-ansible==15.1.0"

#pip install git+https://opendev.org/openstack/kolla-ansible@stable/zed

#Install Ansible Galaxy requirements
kolla-ansible install-deps

##Prepare configs file for deployment

#Create & tuning ansible
echo "Tunning ansible configs"

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
echo "Create kolla config directory"
[ ! -d "/etc/kolla" ] && mkdir -p /etc/kolla
chown $USER:$USER /etc/kolla

#Copy file config template
echo "Copying config teplate files"
cp -r $HOME/private-cloud/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp -r $HOME/private-cloud/share/kolla-ansible/ansible/inventory/* /etc/kolla/

#Backup original config files
echo "Backing up config files"
cd /etc/kolla
cp multinode multinode.bak
cp globals.yml globals.bak

##Git clone config file template
echo "Clone config template files"
cd $HOME
[ -d "private-cloud-templates" ] && rm -rf private-cloud-templates
git clone https://github.com/nhanhd2702/private-cloud-templates.git
cp private-cloud-templates/libs/multinode/multinode /etc/kolla/
cp private-cloud-templates/libs/multinode/globals.yml /etc/kolla/
cp private-cloud-templates/config /etc/kolla/

#Edit inventory file
echo "Append the servers to the inventory file"
## Append the servers to the /etc/kolla/multinode file
for ((i=1; i<=num_servers; i++))
do
sudo sed -i "1i$sv_host ansible_ssh_host=$sv_ip ansible_connection=ssh ansible_user=honeynet ansible_sudo_pass=honeynet.vn network_interface=$sv_int_if neutron_external_interface=$sv_ext_if" /etc/kolla/multinode
done

#Update globals.yml 
echo "Update global variables"
sed -i "s/int_if/$network_if/" /etc/kolla/globals.yml
sed -i "s/ext_if/$neutron_ext_if/" /etc/kolla/globals.yml
sed -i "s/int_vip_ip/$int_vip_address/" /etc/kolla/globals.yml
#
##Generate setup passwords
#kolla-genpwd

## Finish pre-config for openstack 
echo "+--------------------------------------------------------+"
echo "|                                                        |"
echo "|  Preparation is complete.                              |"
echo "|  Please check the multinode & globals file             |"
echo "|  before deploy...                                      |"
echo "|                                                        |"
echo "+--------------------------------------------------------+"
echo "Press Enter to continue."
read -p ""