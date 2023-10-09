#!/bin/bash

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

service_name=$1
service_folder=$2
service_exec=$3
force=$4
if [ -z "$4" ] 
    then
        force=False
fi

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
            