#!/bin/bash

####################################################################################################################
# Help                                                                                                             #
####################################################################################################################
Help () {
    echo "This is a bash script that creates a basic service from a given folder."
    echo "The purpose of this script is to automate service creation."
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
service_name=$1
service_folder=$2
service_exec=$3
force=$4
if [ -z "$4" ] 
    then
        force=False
fi

create_user () {
    if ! id "$service_user" > dev/null 2>&1; then
        sudo useradd -r -m -s /sbin/nologin "$service_user"
    fi
}

copy_files_to_home () {
    sudo cp -r $service_folder /home/$service_user/$service_name
}


main () {
    create_user
    copy_files_to_home
}

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
            