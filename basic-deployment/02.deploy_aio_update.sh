#!/bin/bash

if [ -z "$BYOBU" ]; then
    echo "Byobu is not active. Exiting."
    exit 1
else
    echo "Byobu is active. Start deploying the private-cloud.."
    source "$HOME/private-cloud/bin/activate"

    # Run kolla-ansible bootstrap-servers command
    if ! kolla-ansible -i /etc/kolla/all-in-one bootstrap-servers; then
        echo "An error occurred during bootstrap-servers."
        exit 1
    fi

    # If all commands succeed, you can exit with a success status
    echo "kolla-ansible deploy successfully."
    echo "Continuing to post-deploy."

    if ! kolla-ansible -i /etc/kolla/all-in-one post-deploy; then
        echo "An error occurred during post-deploy."
        exit 1
    fi

    pip install python-openstackclient python-glanceclient python-neutronclient
    source /etc/kolla/admin-openrc.sh
    if ! openstack token issue; then
        echo "An error occurred when issuing the OpenStack token."
        exit 1
    fi

    admin_password=$(grep keystone_admin /etc/kolla/passwords.yml)
    echo "kolla-ansible post-deploy completed successfully. The admin password is $admin_password"
    exit 0
fi
