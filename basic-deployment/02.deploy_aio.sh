#/bin/bash
if [ -z "$BYOBU" ]; then
	echo "Byobu is not active. Exiting."
	exit 1
else
	echo "Byobu is active. Start deploying the private-cloud.."
	source $HOME/private-cloud/bin/activate
	# Run kolla-ansible bootstrap-servers command
	kolla-ansible -i /etc/kolla/all-in-one bootstrap-servers
	# Check the exit status of the kolla-ansible bootstrap-servers command
	if [ $? -ne 0 ]; then
		echo "An error occurred during bootstrap-servers."
		exit 1
	else
		kolla-ansible -i /etc/kolla/all-in-one prechecks
		if [ $? -ne 0 ]; then
			echo "An error occurred during prechecks."
			exit 1
		else
			kolla-ansible -i /etc/kolla/all-in-one deploy
			if [ $? -ne 0 ]; then
				echo "An error or failure occurred during deploy ."
				exit 1
			else
				echo "kolla-ansible deploy successfully."
				echo "Continuing to post-deploy."
				kolla-ansible post-deploy
				if [ $? -ne 0 ]; then
					echo "An error occurred during post-deploy."
					exit 1
				else
					pip install python-openstackclient python-glanceclient python-neutronclient
					source /etc/kolla/admin-openrc.sh
					openstack token issue
					admin_password=cat /etc/kolla/passwords.yml | grep keystone_admin
					echo "kolla-ansible post-deploy completed successfully. The admin password is $admin_password"
					exit 0
				fi
			fi
		fi
	fi
fi
