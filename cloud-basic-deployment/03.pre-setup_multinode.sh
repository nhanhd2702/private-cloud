#!/bin/bash

## Check privilege
echo "Checking privileges"
die() {
  echo "ERROR: $1"
  exit 1
}

[ "$(whoami)" = "root" ] || die "This script must be run as root"

# Servers definition
declare -a sv_host_array
declare -a neutron_int_if_array
declare -a neutron_ext_if_array
config_line=""
echo "Enter the number of servers: "
read -r num_servers

# Server information.
for ((i=1; i<=num_servers; i++))
do
    read -r -p "Enter the name of server $i (example: serv-0$i): " sv_host
    read -r -p "Enter the IP address of server $i (example: 192.168.10.$i):  " sv_ip

    # Prompt for the network interface and neutron external interface
    read -r -p "Enter the network interface for server $i (example: ens160):  " neutron_int_if
    read -r -p "Enter the neutron external interface for server $i (example: ens192): " neutron_ext_if
    neutron_int_if_array[i]=$neutron_int_if
    neutron_ext_if_array[i]=$neutron_ext_if
    config_line="$config_line\n$sv_host ansible_ssh_host=$sv_ip ansible_connection=ssh ansible_user=honeynet ansible_sudo_pass=honeynet.vn network_interface=$neutron_int_if neutron_external_interface=$neutron_ext_if"
    sv_host_array[i]=$sv_host
done
read -r -p "Enter Internal VIP Address (example: 192.168.10.100): " int_vip_address


# Generate an SSH key pair (without a passphrase)
echo "Enter SSH Login Username (example: admin): "
read -r login_name

ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy the SSH public key to the user's authorized_keys file
for ((i=1; i<=num_servers; i++))
do
    # Copy the SSH public key to the user's authorized_keys file
    if ssh-copy-id -i ~/.ssh/id_rsa.pub "$login_name@${sv_host_array[$i]}"; then
        echo "SSH key copied to $login_name@${sv_host_array[$i]}"
    else
        echo "Failed to copy SSH key to $login_name@${sv_host_array[$i]}"
    fi
done


## Update system packages
echo "Updating your system packages"

apt update && sudo apt upgrade -y

apt autoremove -y

# Set date-time
echo "Setting date & time"

timedatectl set-timezone Asia/Ho_Chi_Minh

# Install python libraries & packages
echo "Install python libraries & packages"
apt install python3-pip python3-dev python3-docker libffi-dev gcc libssl-dev git -y

# Install virtualenv
echo "Setting up virtual environment"
apt install python3-venv python3-virtualenv -y

# Create virtual environment
if [ ! -d "/usr/local/private-cloud" ]; then
    python3 -m venv "/usr/local/private-cloud"
else
    rm -rf "/usr/local/private-cloud"
    python3 -m venv "/usr/local/private-cloud"
fi

# Activate virtual environment
echo "Activate venv & setting up kolla packages"
source "/usr/local/private-cloud/bin/activate" || exit

# Upgrade pip tools
pip install -U pip

# Install Ansible
pip install -U 'ansible>=4,<6'

# Install kolla-ansible and its dependencies using pip
pip install "kolla-ansible==15.3.0"

# pip install git+https://opendev.org/openstack/kolla-ansible@stable/zed

# Install Ansible Galaxy requirements
kolla-ansible install-deps

## Prepare config files for deployment

# Create & tuning ansible
echo "Tuning ansible configs"

if [[ ! -e /etc/ansible/ansible.cfg ]]; then
    mkdir -p /etc/ansible
    touch /etc/ansible/ansible.cfg
fi

# Tuning ansible
cat << EOF > /etc/ansible/ansible.cfg
[defaults]
host_key_checking=False
pipelining=True
forks=100
EOF

# Create the /etc/kolla directory
echo "Create kolla config directory"
[ ! -d "/etc/kolla" ] && mkdir -p /etc/kolla
chown "$USER:$USER" /etc/kolla

# Copy file config template
echo "Copying config template files"
cp -r /usr/local/private-cloud/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp -r /usr/local/private-cloud/share/kolla-ansible/ansible/inventory/* /etc/kolla/

# Backup original config files
echo "Backing up config files"
cd /etc/kolla || exit
cp multinode multinode.bak
cp globals.yml globals.bak

## Git clone config file template
echo "Clone config template files"
[ -d "/tmp/private-cloud-templates" ] && rm -rf "/tmp/private-cloud-templates" && git clone https://github.com/nhanhd2702/private-cloud-templates.git
cp /tmp/private-cloud-templates/basic-deployment/libs/multinode/multinode /etc/kolla/
cp /tmp/private-cloud-templates//basic-deployment/libs/multinode/globals.yml /etc/kolla/
cp -R /tmp/private-cloud-templates/config /etc/kolla/

# Edit inventory file
echo "Append the servers to the inventory file"
## Append the servers to the /etc/kolla/multinode file
sed -i "1i$config_line" /etc/kolla/multinode && sed -i "1s/^n//" /etc/kolla/multinode

# Update globals.yml
echo "Update global variables"
sed -i "s/int_if/${neutron_int_if_array[1]}/" /etc/kolla/globals.yml
sed -i "s/ext_if/${neutron_ext_if_array[1]}/" /etc/kolla/globals.yml
sed -i "s/int_vip_ip/$int_vip_address/" /etc/kolla/globals.yml

## Generate setup passwords
# kolla-genpwd

## Finish pre-config for OpenStack
echo "+---------------------------------------------------------+"
echo "|                                                         |"
echo "| Preparation is complete.                                |"
echo "| Please check the multinode & globals file before deploy |"
echo "|                                                         |"
echo "+---------------------------------------------------------+"
read -r -p "Press Enter to continue."