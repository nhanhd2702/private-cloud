#!/bin/bash

# Function to prompt user for input
prompt_user() {
    read -r -p "$1" response
    echo "$response"
}

# Function to create or update a configuration file
create_or_update_config_file() {
    local file_path="$1"
    local content="$2"

    if [[ ! -e "$file_path" ]]; then
        mkdir -p "$(dirname "$file_path")"
        touch "$file_path"
    fi

    echo -e "$content" > "$file_path"
}

# Function to copy SSH public key to remote server
copy_ssh_key() {
    local user="$1"
    local host="$2"
    ssh-copy-id -i ~/.ssh/id_rsa.pub "$user@$host"
}

# Function to install system packages
install_system_packages() {
    echo "Updating system packages..."
    apt update && apt upgrade -y
    apt autoremove -y
}

# Function to set date and time
set_date_time() {
    echo "Setting date & time..."
    timedatectl set-timezone Asia/Ho_Chi_Minh
}

# Function to install Python and virtual environment
install_python_and_venv() {
    echo "Installing Python and virtual environment..."
    apt install python3-pip python3-dev python3-docker libffi-dev gcc libssl-dev git -y
    apt install python3-venv python3-virtualenv -y
}

# Function to create and activate virtual environment
create_and_activate_venv() {
    echo "Setting up virtual environment..."
    python3 -m venv "/usr/local/private-cloud"
    source "/usr/local/private-cloud/bin/activate" || exit
}

# Function to install Ansible and Kolla-Ansible
install_ansible_and_kolla() {
    echo "Installing Ansible and Kolla-Ansible..."
    pip install -U pip
    pip install -U 'ansible>=4,<6'
    pip install "kolla-ansible==15.3.0"
    kolla-ansible install-deps
}

# Function to prepare config files for deployment
prepare_config_files() {
        echo "Preparing configuration files for deployment..."

    # Create or update Ansible configuration file
    ansible_cfg_path="/etc/ansible/ansible.cfg"
    ansible_cfg_content="[defaults]\nhost_key_checking=False\npipelining=True\nforks=100"
    create_or_update_config_file "$ansible_cfg_path" "$ansible_cfg_content"

    # Create the /etc/kolla directory
    kolla_dir="/etc/kolla"
    echo "Create kolla config directory..."
    [ ! -d "$kolla_dir" ] && mkdir -p "$kolla_dir"
    chown "$USER:$USER" "$kolla_dir"

    # Copy file config template
    echo "Copying config template files..."
    cp -r /usr/local/private-cloud/share/kolla-ansible/etc_examples/kolla/* "$kolla_dir"
    cp -r /usr/local/private-cloud/share/kolla-ansible/ansible/inventory/* "$kolla_dir"

    # Backup original config files
    echo "Backing up config files..."
    cd "$kolla_dir" || exit
    cp multinode multinode.bak
    cp globals.yml globals.bak

    # Git clone config file template
    echo "Clone config template files..."
    cloud_dir="/usr/local"
    cd $cloud_dir
    [ -d "private-cloud-templates" ] && rm -rf private-cloud-templates 
    git clone https://github.com/nhanhd2702/private-cloud-templates.git
    cp "$cloud_dir/private-cloud-templates/cloud-basic-deployment/libs/multinode/multinode" "$kolla_dir/"
    cp "$cloud_dir/private-cloud-templates/cloud-basic-deployment/libs/multinode/globals.yml" "$kolla_dir/"
    cp -R "$cloud_dir/private-cloud-templates/vlan-config/*" "$kolla_dir/"

    # Edit inventory file
    echo "Append the servers to the inventory file..."
    sed -i "1i$config_line" "$kolla_dir/multinode" && sed -i "1s/^n//" "$kolla_dir/multinode"

    # Update globals.yml
    echo "Update global variables..."
    sed -i "s/int_if/${neutron_int_if_array[1]}/" "$kolla_dir/globals.yml"
    sed -i "s/ext_if/${neutron_ext_if_array[1]}/" "$kolla_dir/globals.yml"
    sed -i "s/int_vip_ip/$int_vip_address/" "$kolla_dir/globals.yml"

    echo "Configuration files preparation complete."
}

# Function to display completion message
display_completion_message() {
    echo "+---------------------------------------------------------+"
    echo "|                                                         |"
    echo "| Preparation is complete.                                |"
    echo "| Double-check  MULTINODE & GLOBALS file before deploy    |"
    echo "|                                                         |"
    echo "+---------------------------------------------------------+"
    read -r -p "Press Enter to continue."
}

# Main script

# Function to display error and exit
die() {
    echo "ERROR: $1"
    exit 1
}

# Function to check if the script is run as root
check_root_privilege() {
    echo "Checking privileges..."
    [ "$(whoami)" = "root" ] || die "This script must be run as root"
}

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
    sv_host=$(prompt_user "Enter the name of server $i (example: serv-0$i): ")
    sv_ip=$(prompt_user "Enter the IP address of server $i (example: 192.168.10.$i): ")

    # Prompt for the network interface and neutron external interface
    neutron_int_if=$(prompt_user "Enter the network interface for server $i (example: ens160): ")
    neutron_ext_if=$(prompt_user "Enter the neutron external interface for server $i (example: ens192): ")

    neutron_int_if_array[i]=$neutron_int_if
    neutron_ext_if_array[i]=$neutron_ext_if

    config_line="$config_line\n$sv_host ansible_ssh_host=$sv_ip ansible_connection=ssh ansible_user=honeynet ansible_sudo_pass=honeynet.vn network_interface=$neutron_int_if neutron_external_interface=$neutron_ext_if"

    sv_host_array[i]=$sv_host
done

# Prompt for Internal VIP Address
int_vip_address=$(prompt_user "Enter Internal VIP Address (example: 192.168.10.100): ")

# Prompt for SSH Login Username
login_name=$(prompt_user "Enter SSH Login Username (example: admin): ")

# Generate an SSH key pair (without a passphrase)
echo "Generating SSH key pair..."
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy the SSH public key to the user's authorized_keys file
for ((i=1; i<=num_servers; i++))
do
    if copy_ssh_key "$login_name" "${sv_host_array[$i]}"; then
        echo "SSH key copied to $login_name@${sv_host_array[$i]}"
    else
        echo "Failed to copy SSH key to $login_name@${sv_host_array[$i]}"
    fi
done

# Install system packages
install_system_packages

# Set date-time
set_date_time

# Install Python libraries & packages
install_python_and_venv

# Create and activate virtual environment
create_and_activate_venv

# Install Ansible and Kolla-Ansible
install_ansible_and_kolla

# Prepare config files for deployment
prepare_config_files

# Display completion message
display_completion_message
