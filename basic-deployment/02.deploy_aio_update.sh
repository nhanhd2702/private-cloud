#!/bin/bash

if byobu list-sessions 2>&1 | grep -q "no server running"; then
    echo "No active Byobu session. Exiting." && exit 1
else
	echo "Byobu is active. Start deploying the private-cloud.."
	source usr/local/private-cloud/bin/activate

	# Functions for command execution and error handling
	execute_command() {
	    $1
	    if [ $? -ne 0 ]; then
	        echo "An error occurred during $2."
	        exit 1
	    fi
	}

	# Run Kolla-ansible commands with error handling
	execute_command "kolla-ansible -i /etc/kolla/all-in-one bootstrap-servers" "bootstrap-servers"
	execute_command "kolla-ansible -i /etc/kolla/all-in-one prechecks" "prechecks"
	execute_command "kolla-ansible -i /etc/kolla/all-in-one deploy" "deploy"
	execute_command "kolla-ansible post-deploy" "post-deploy"

	# Install OpenStack clients, source admin credentials, and check token issuance
	pip install python-openstackclient python-glanceclient python-neutronclient
	source /etc/kolla/admin-openrc.sh
	openstack token issue

	# Print admin password
	admin_password=$(grep keystone_admin /etc/kolla/passwords.yml)
	echo "kolla-ansible post-deploy completed successfully. The admin password is $admin_password"
	exit 0
fi