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

does_service_exist () {
    does_exist=$(systemctl list-units --full -all | grep -Fq "$1.service")
    if [ "$does_exist" ]; then
        return 0
    else
        return 1
    fi
}

does_dir_exist () {
    if [ -d "$1" ]; then
        return 0
    else    
        return 1
    fi
}

does_file_exist () {
    local file="$1"
    local log_file="$2"
    if [ ! -f "$file" ]; then
        echo "The file provided does not exist, or is not a regular file. Exisiting script." | tee "$log_file"
        exit
    fi
}

get_cli_arguments () {
    echo "Enter service name: " 
    read -r service_name
    local log_file="/var/log/$service_name"
    echo "Service: $service_name" >> "$log_file"

    echo "Enter full path to service folder: " | tee "$log_file"
    read -r service_folder
    echo "$service_folder" >> "$log_file"
    if [ $(does_dir_exist "$service_folder") -eq 1 ]; then
        echo "The directory provided does not exist. Exisiting script." | tee "$log_file"
        exit
    fi

    echo "Enter relative path to service executable (from inside the service folder): " | tee "$log_file"
    read -r service_exec
    echo "$service_exec" >> "$log_file"
    does_exec_exist "$service_exec"

    echo "Do you want the script to run silently? (Y/N) " | tee "$log_file"
    read -r force
    echo "$force" >> "$log_file"
    echo "Starting script with given arguments" | tee "$log_file"
}

create_user () {
    local username="$1"
    if ! id "$username" > /dev/null 2>&1; then
        {
            sudo useradd -r -m -s /sbin/nologin "$username" 
            echo "service user created successfully."
            } || {
            echo "service user could not be created. Exisiting script."
            exit
        }
    fi
}

move_service_files () {
    local original_folder_path="$1"
    local new_folder_path="$2"
    local exec_relative_path="$3"
    local new_script_path="$4"
    local user="$5"
    {
        sudo cp -r "$original_folder_path" "$new_folder_path"
        sudo mv "$new_folder_path/$exec_relative_path" "$new_script_path"
        sudo chmod 744 "$new_script_path"
        sudo chown "$user" "$new_script_path"
    } || {
        echo "could not move service files to service user directory. Exisiting script."
        remove_service
    }
}

create_service_file () {
    local user="$1"
    local name_of_service="$2"
    local service_file_template="$3"
    local service_folder_path="$4"
    local exec_path="$5"
    {
        local service_file="/home/$user/$name_of_service/$name_of_service.service"
        sudo cp -r "$service_file_template" "$service_file"
        sudo sed -i "s@<user>@$user@g" "$service_file"
        sudo sed -i "s@<working_directory>@$service_folder_path@g" "$service_file"
        sudo sed -i "s@<script_path>@$exec_path@g" "$service_file"
        sudo mv "$service_file" "/etc/systemd/system/$name_of_service.service"
    } || {
        echo "could not create service file. Exisiting script."
        remove_service
    }
}

reload_service () {
    local service="$1"
    sudo systemctl daemon-reload
    sudo systemctl start "$service.service"
}

check_service_status () {
    local service="$1"
    if [ "$(systemctl is-active "$service")" = "active" ]; then
        echo "Service started successfully"
    else
        echo "Service could not be started"
    fi
}

start_service () {
    local service="$1"
    if [ "$force" = "Y" ]; then
        reload_service "$service"
        check_service_status "$service"
    else
        echo "In order for the service to start the systemctl daemon needs to be reloaded. reload? (Y/N): "
        read -r reset_daemon
        if [ "$reset_daemon" = "Y" ]; then
            reload_service "$service"
            check_service_status "$service"
        else
            echo "Service created but was not run."
        fi
    fi
}

main () {
    service_user="service_agent"
    service_template="service_template.txt"

    get_cli_arguments

    log_file="/var/log/$service_name"
    service_folder_dest="/home/$service_user/$service_name"
    script_path="/usr/local/bin/$service_name.sh"

    create_user "$service_user" "$log_file"

    if [ "$force" != "Y" ] && [ $(does_dir_exist $service_folder_dest) -eq 0 ]; then
        echo "Service Folder $service_folder_dest already exists, and needs to be overriden. override folder? (Y/N): "
        read -r move_service_files_prompt
        if [ "$move_service_files_prompt" = "Y" ]; then
            move_service_files "$service_folder" "$service_folder_dest" "$service_exec" "$script_path" $service_user
        fi
    else
        move_service_files "$service_folder" "$service_folder_dest" "$service_exec" "$script_path" $service_user
    fi

    create_service_file $service_user "$service_name" $service_template "$service_folder_dest" "$script_path"

    start_service "$service_name"
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
            