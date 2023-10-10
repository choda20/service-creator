#!/bin/bash

####################################################################################################################
# Help                                                                                                             #
####################################################################################################################
Help () {
    echo "This is a bash script that creates a basic service from a given folder."
    echo "The purpose of this script is to automate service creation."
    echo "In order for the script to work it has to be run by a user with root privileges."
    echo "the script gets 4 parameters:"
    echo "  - service_name: the desired name of the service"
    echo "  - service_folder: the folder of the service files"
    echo "  - service_exec: the service executable"
    echo "  - force: a parameter signaling if the script should get user input (False, default option)"
    echo "           or show logs only (True)"
}

####################################################################################################################
# Main Program                                                                                                     #
####################################################################################################################
service_user="service_agent"
service_template="service_template.txt"
service_name=$1
service_folder=$2
service_exec=$3
service_folder_dest="/home/$service_user/$service_name"
script_path="/usr/local/bin/$service_name.sh"
force=$4
if [ -z "$4" ] 
    then
        force=False
fi

create_user () {
    if ! id "$service_user" > /dev/null 2>&1; then
        sudo useradd -r -m -s /sbin/nologin "$service_user"
    fi
}

copy_files () {
    sudo cp -r "$service_folder" "$service_folder_dest"
    sudo mv "$service_folder_dest/$service_exec" "$script_path"
    sudo chmod 744 "$script_path"
    sudo chown "$service_user" "$script_path"
}

create_service_file () {
    service_file="/home/$service_user/$service_name/$service_name.service"
    sudo cp -r $service_template "$service_file"
    sudo sed -i "s@<user>@$service_user@g" "$service_file"
    sudo sed -i "s@<working_directory>@$service_folder_dest@g" "$service_file"
    sudo sed -i "s@<script_path>@$script_path@g" "$service_file"
    sudo mv "$service_file" "/etc/systemd/system/$service_name.service"
}

start_service () {
    sudo systemctl daemon-reload
    sudo systemctl start "$service_name.service"
}

check_service_status () {
    status=$(systemctl is-active --quiet "$service_name")
    if [ "$status" = "active" ]; then
        echo "Service started successfully"
    else
        echo "Service could not be started"
    fi
}

main () {
    create_user
    copy_files
    create_service_file
    start_service
    check_service_status
}

main
####################################################################################################################
# Flag Handling                                                                                                    #
####################################################################################################################
while getopts ":h" option; do
    case $option in
        h) # display help
            Help
            exit;;
        \?) # incorrect option
            echo "Error: Invalid option"
            exit;;
    esac
done
            