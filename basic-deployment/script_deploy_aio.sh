#/bin/bash
echo "Make sure activate byobu to keep session"
source $HOME/private-cloud/bin/activate
# Run kolla-ansible bootstrap-servers command
kolla-ansible -i all-in-one bootstrap-servers
# Check the exit status of the kolla-ansible bootstrap-servers command
if [ $? -ne 0 ]; then
  echo "An error or failure occurred during kolla-ansible bootstrap-servers execution."
  exit 1
else
  echo "kolla-ansible bootstrap-servers completed successfully."
  echo "Continuing to the next step: kolla-ansible -i all-in-one prechecks."
  kolla-ansible -i all-in-one prechecks
  if [ $? -ne 0 ]; then
    echo "An error or failure occurred during kolla-ansible prechecks execution."
    exit 1
  else
    echo "kolla-ansible prechecks completed successfully."
    echo "Continuing to the next step: kolla-ansible -i all-in-one deploy."
    kolla-ansible -i all-in-one deploy
    if [ $? -ne 0 ]; then
      echo "An error or failure occurred during kolla-ansible deploy execution."
      exit 1
    else
      echo "kolla-ansible deploy completed successfully."
      echo "Continuing to the next step: kolla-ansible post-deploy."
      kolla-ansible post-deploy
      if [ $? -ne 0 ]; then
        echo "An error or failure occurred during kolla-ansible post-deploy execution."
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
