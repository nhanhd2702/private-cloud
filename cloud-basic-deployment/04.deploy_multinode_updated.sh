#!/bin/bash

# Check for an active Byobu session
if byobu list-sessions 2>&1 | grep -q "no server running"; then
    echo "No active Byobu session. Exiting." && exit 1
else
    echo "Byobu is active. Start deploying the multinode private cloud."

    # Activate virtual environment
    source /usr/local/private-cloud/bin/activate

    # Functions for command execution and error handling
    execute_command() {
        $1
        if [ $? -ne 0 ]; then
            echo "An error occurred during $2."
            exit 1
        fi
    }

    # Run Ansible ping to check connectivity
    execute_command "ansible -i /etc/kolla/multinode all -m ping" "Ansible Ping"

    # Generate Kolla passwords
    execute_command "kolla-genpwd" "Kolla Password Generation"

    # Run Kolla-ansible commands with error handling
    execute_command "kolla-ansible -i /etc/kolla/multinode bootstrap-servers" "Bootstrap Servers"
    execute_command "kolla-ansible -i /etc/kolla/multinode prechecks" "Prechecks"
    execute_command "kolla-ansible -i /etc/kolla/multinode deploy" "Deploy"
    execute_command "kolla-ansible post-deploy" "Post-Deploy"

    # Install CLI packages
    execute_command "pip install python-openstackclient python-glanceclient python-neutronclient"

    # Create token issue
    source /etc/kolla/admin-openrc.sh
    openstack token issue

    # Print admin password
    admin_password=$(grep keystone_admin /etc/kolla/passwords.yml)
    echo "kolla-ansible post-deploy completed successfully. The admin password is $admin_password"
    exit 0
fi
