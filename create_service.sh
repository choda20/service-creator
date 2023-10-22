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

does_dir_exist () {
    local dir="$1"
    local log_file="$2"
    if [ ! -d "$dir" ]; then
        echo "The directory provided does not exist. Exiting script." | tee -a "$log_file"
        exit
    fi
}

does_file_exist () {
    local file="$1"
    local log_file="$2"
    if [ ! -f "$file" ]; then
        echo "The file provided does not exist, or is not a regular file. Exiting script." | tee -a "$log_file"
        exit
    fi
}

validate_Y/N () {
    local answer="$1"
    local log_file="$2"
    if [ "$answer" != "Y" ] && [ "$answer" != "N" ]; then
        echo "Invalid answer: '$answer', Exiting script." | tee -a "$log_file"
        exit
    else 
        echo "Valid answer: '$answer'" >> "$log_file"
    fi
}

get_cli_arguments () {
    echo "Enter service name: " 
    read -r service_name
    sudo mkdir "/var/log/service_creator/" >> /dev/null 2>&1
    local log_file="/var/log/service_creator/$service_name"

    echo "-------------- Service: $service_name --------------" >> "$log_file"
    
    echo "Enter full path to service folder: " | tee -a "$log_file"
    read -r service_folder
    echo "$service_folder" >> "$log_file"
    does_dir_exist "$service_folder" "$log_file"

    echo "Enter relative path to service executable (from inside the service folder): " | tee -a "$log_file"
    read -r service_exec
    echo "$service_exec" >> "$log_file"
    does_file_exist "$service_folder/$service_exec" "$log_file"

    echo "Do you want the script to run silently? (Y/N) " | tee -a "$log_file"
    read -r force
    validate_Y/N "$force" "$log_file"
    echo "Starting script with given arguments" | tee -a "$log_file"
}

create_user () {
    local username="$1"
    local log_file="$2"
    if ! id "$username" > /dev/null 2>&1; then
        {
            sudo useradd -r -m -s /sbin/nologin "$username" 
            echo "service user created successfully." | tee -a "$log_file"
            } || {
            echo "service user could not be created. Exiting script." | tee -a "$log_file"
            exit
        }
    else
        echo "User already exists, preceeding" >> "$log_file"
    fi
}

move_service_files () {
    local original_folder_path="$1"
    local new_folder_path="$2"
    local exec_relative_path="$3"
    local new_script_path="$4"
    local user="$5"
    local force="$6"
    local log_file="$7"
    local move_files="Y"
    {
        if [ "$force" != "Y" ] && [ -d "$new_folder_path" ]; then
            echo "Service Folder $new_folder_path already exists, and needs to be overriden. override folder? (Y/N): " | tee -a "$log_file"
            read -r move_files
            validate_Y/N "$move_files" "$log_file"
        fi

        if [ "$move_files" = "Y" ]; then
            sudo cp -r "$original_folder_path" "$new_folder_path"
            sudo mv "$new_folder_path/${original_folder_path##*/}/$exec_relative_path" "$new_script_path"
            sudo chmod 744 "$new_script_path"
            sudo chown "$user" "$new_script_path"
            echo "Moved service files to service folder" | tee -a "$log_file"
        fi
        
    } || {
        echo "could not move service files to service user directory. Exiting script." | tee -a "$log_file"
        exit
    }
}

create_service_file () {
    local user="$1"
    local name_of_service="$2"
    local service_file_template="$3"
    local service_folder_path="$4"
    local exec_path="$5"
    local force="$6"
    local log_file="$7"
    local service_file="/home/$user/$name_of_service/$name_of_service.service"
    local service_file_dest="/etc/systemd/system/$name_of_service.service"
    local override_service_file="Y"
    {
        if [ "$force" != "Y" ] && [ -f "$service_file_dest" ]; then   
            echo "Service file already exists, override it? (Y/N) " | tee -a "$log_file"
            read -r override_service_file
            validate_Y/N "$override_service_file" "$log_file"
        fi

        if [ "$override_service_file" = "Y" ]; then
            sudo cp -r "$service_file_template" "$service_file"
            sudo sed -i "s@<user>@$user@g" "$service_file"
            sudo sed -i "s@<working_directory>@$service_folder_path@g" "$service_file"
            sudo sed -i "s@<script_path>@$exec_path@g" "$service_file"
            sudo mv "$service_file" "$service_file_dest"
            echo "Created the service configuration file" | tee -a "$log_file"
        fi 

    } || {
        echo "could not create service file. Exiting script." | tee -a "$log_file"
        exit
    }
}

reload_service () {
    local service="$1"
    sudo systemctl daemon-reload
    sudo systemctl start "$service.service"
}

check_service_status () {
    local service="$1"
    local log_file="$2"
    if [ "$(systemctl is-active "$service")" = "active" ]; then
        echo "Service started successfully" | tee -a "$log_file"
    else
        echo "Service could not be started" | tee -a "$log_file"
    fi
}

start_service () {
    local service="$1"
    local force="$2"
    local log_file="$3"
    local reset_daemon="Y"

    
    if [ "$force" != "Y" ]; then
        echo "In order for the service to start the systemctl daemon needs to be reloaded. reload? (Y/N): " | tee -a "$log_file"
        read -r reset_daemon
        validate_Y/N "$reset_daemon" "$log_file"
    fi

    if [ "$reset_daemon" = "Y" ]; then
        reload_service "$service" 
        check_service_status "$service" "$log_file"
    else
        echo "Service created but was not run." | tee -a "$log_file"
    fi
}

main () {
    service_user="service_agent"
    service_template="service_template.txt"

    get_cli_arguments

    log_file="/var/log/service_creator/$service_name"
    service_folder_dest="/home/$service_user/$service_name"
    script_path_dest="/usr/local/bin/$service_name.sh"

    create_user "$service_user" "$log_file"

    move_service_files "$service_folder" "$service_folder_dest" "$service_exec" "$script_path_dest" $service_user  "$force" "$log_file"

    create_service_file $service_user "$service_name" $service_template "$service_folder_dest" "$script_path_dest" "$force" "$log_file"

    start_service "$service_name" "$force" "$log_file"
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
            