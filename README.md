Step 1: Setup cinder_volume before run the script (or setup free disk for cinder_volume)

Step 2: Go to script_deploy folder

Step 3: Open file script_deploy_aio, change values of cinder_volume_disk, internal & external interface to match the installation environment

Step 4: Change permission to run the script

Step 4: Run the script

Step 5: Make sure prechecks is no error , then run the command " kolla-ansible -i /etc/kolla/all-in-one deploy
