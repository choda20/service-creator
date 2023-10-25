#!/bin/bash
# TODO: each TODO will be relevant to the line above it.
# Feel free to ask me for details
# Overall the script is well made and organized

# TODO: Working with git
# 3 branches
# main - production ready, CR'ed code
# dev - development code, CR'ed code which has yet to be used on production
# feat/name fix/name - experimental code, untested, may not work

# YOU MAY ONLY MERGE upon a cr from me
# This way we will have a version for every need and I will be able to use git's review features

####################################################################################################################
# Help                                                                                                             #
####################################################################################################################
Help () {
    echo "This is a bash script that creates a basic service from a given folder."
    echo "The purpose of this script is to automate service creation."
    echo "In order for the script to work it has to be run by a user with root privileges."
    echo "Script Flags:"
    echo "  -i: interactive mode, gets input from the user instead of flag passing"
    echo "  -f: a path to the folder of the service files"
    echo "  -e: relative path of the service exec inside the folder"
    echo "  -n: the name of the service"
    echo "  -s: should the script ask for confrimation when deleting files(Y/N, y/n)"
    echo "Important note: flag i cannot be used with f/e/n/s, and flags f/e/n/s must be used together."
}

####################################################################################################################
# Main Program                                                                                                     #
####################################################################################################################

does_dir_exist () {
    local dir="$1"
    local log_file="$2"
    if [ ! -d "$dir" ]; then
        echo "The directory provided does not exist. Please try again." | tee -a "$log_file"
        return 0
    else
        return 1
    fi
}

is_file_exec () {
    local file="$1"
    local log_file="$2"
    local file_type=$(file -b "$file")
    if [ ! -x "$file" ] && [[ "$file_type" != *script* ]]; then
        echo "The file provided does not exist, or is not a script/executable file. Please try again." | tee -a "$log_file"
        return 0
    else
        return 1
    fi
}

validate_Y/N () {
    local answer="$1"
    local log_file="$2"
    # TODO: allow y and n as possible answers
    # Allow for another input upon failure, do not exit
    # This is not user friendly
    local valid_answers=("Y" "N" "y" "n")
    if [[ ${valid_answers[*]} =~ $answer ]]; then
        echo "Valid answer: '$answer'" >> "$log_file"
        return 1
    else 
        echo "Invalid answer: '$answer', Please try again." | tee -a "$log_file"
        return 0
    fi
}

get_cli_arguments () {
    echo "Enter service name: " 
    read -r service_name
    # TODO: Nice ui, but this makes the service unusable when running in another script
    # For example, a cicd flow
    # Use flags for information ~you may leave this option as a -i option (interactive)~
    sudo mkdir -p "/var/log/service_creator/" 
    # TODO: Look into the -p flag ^^
    local log_file="/var/log/service_creator/$service_name"

    echo "-------------- Service: $service_name --------------" >> "$log_file"
    
    local valid_service_folder=0
    while [ $valid_service_folder -eq 0 ]; do
        echo "Enter full path to service folder: " | tee -a "$log_file"
        read -r service_folder
        echo "$service_folder" >> "$log_file"
        does_dir_exist "$service_folder" "$log_file"
        valid_service_folder=$?
    done

    local valid_service_exec=0
    while [ $valid_service_exec -eq 0 ]; do
        echo "Enter relative path to service executable (from inside the service folder): " | tee -a "$log_file"
        read -r service_exec
        echo "$service_exec" >> "$log_file"
        is_file_exec "$service_folder/$service_exec" "$log_file"
        valid_service_exec=$?
    done

    local valid_silent=0
    while [ $valid_silent -eq 0 ]; do
        echo "Do you want the script to run silently? (Y/N) " | tee -a "$log_file"
        read -r silent
        validate_Y/N "$silent" "$log_file"
        valid_silent=$?
    done

    echo "Starting script with given arguments" | tee -a "$log_file"
}

check_flag_arguments () {
    sudo mkdir -p "/var/log/service_creator/" 
    local log_file="/var/log/service_creator/$service_name"

    echo "-------------- Service: $service_name --------------" >> "$log_file"
    
    echo "$service_folder" >> "$log_file"
    does_dir_exist "$service_folder" "$log_file"
    valid_service_folder=$?
    if [ $valid_service_folder -eq 0 ]; then
        echo "-f flag value is invalid. try again." | tee -a "$log_file"
        exit
    fi

    echo "$service_exec" >> "$log_file"
    is_file_exec "$service_folder/$service_exec" "$log_file"
    valid_service_exec=$?    
    if [ $valid_service_exec -eq 0 ]; then
        echo "-e flag value is invalid. try again." | tee -a "$log_file"
        exit
    fi

    validate_Y/N "$silent" "$log_file"
    valid_silent=$?
    if [ $valid_silent -eq 0 ]; then
        echo "-s flag value is invalid. try again." | tee -a "$log_file"
        exit
    fi

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
    local silent="$6"
    local log_file="$7"
    local move_files="Y"
    {
        if [ "$silent" != "Y" ] && [ "$silent" != "y" ] && [ -d "$new_folder_path" ]; then
            echo "Service Folder $new_folder_path already exists, and needs to be overriden. override folder? (Y/N): " | tee -a "$log_file"
            read -r move_files
            validate_Y/N "$move_files" "$log_file"
        fi

        if [ "$move_files" = "Y" ] || [ "$move_files" = "y" ]; then
            sudo cp -r "$original_folder_path" "$new_folder_path"
            sudo mv "$new_folder_path/${original_folder_path##*/}/$exec_relative_path" "$new_script_path"
            # TODO: look into this line
            # Place the executable in a new folder
            # This allows for dlls or configuration files to be used by the program
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
    local silent="$6"
    local log_file="$7"
    local service_file="/etc/systemd/system/$name_of_service.service"
    # TODO: Why do you use a temporary file for the service file?
    local override_service_file="Y"
    {
        if [ "$silent" != "Y" ] && [ "$silent" != "y" ] && [ -f "$service_file" ]; then   
            echo "Service file already exists, override it? (Y/N) " | tee -a "$log_file"
            read -r override_service_file
            validate_Y/N "$override_service_file" "$log_file"
        fi

        if [ "$override_service_file" = "Y" ] || [ "$override_service_file" = "y" ]; then
            sudo cp -r "$service_file_template" "$service_file"
            sudo sed -i "s@<user>@$user@g" "$service_file"
            sudo sed -i "s@<working_directory>@$service_folder_path@g" "$service_file"
            sudo sed -i "s@<script_path>@$exec_path@g" "$service_file"
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
    local silent="$2"
    local log_file="$3"
    local reset_daemon="Y"

    
    if [ "$silent" != "Y" ] && [ "$silent" != "y" ]; then
        echo "In order for the service to start the systemctl daemon needs to be reloaded. reload? (Y/N): " | tee -a "$log_file"
        read -r reset_daemon
        validate_Y/N "$reset_daemon" "$log_file"
    fi

    if [ "$reset_daemon" = "Y" ] || [ "$reset_daemon" = "y" ]; then
        reload_service "$service" 
        check_service_status "$service" "$log_file"
    else
        echo "Service created but was not run." | tee -a "$log_file"
    fi
}

main () {
    service_user="service_agent"
    service_template="service_template.txt"

    log_file="/var/log/service_creator/$service_name"
    service_folder_dest="/home/$service_user/$service_name"
    script_path_dest="/usr/local/bin/$service_name/$service_name.sh"

    create_user "$service_user" "$log_file"

    move_service_files "$service_folder" "$service_folder_dest" "$service_exec" "$script_path_dest" $service_user  "$silent" "$log_file"

    create_service_file $service_user "$service_name" $service_template "$service_folder_dest" "$script_path_dest" "$silent" "$log_file"

    start_service "$service_name" "$silent" "$log_file"
}


####################################################################################################################
# Flag Handling                                                                                                    #
####################################################################################################################
service_name=0
service_folder=0
service_exec=0
silent=0
interactive_mode_flag=0
while getopts ":ihn:f:e:s:" option; do
    case $option in
        i) # Interactive mode
            interactive_mode_flag=1
            ;;
        n) # Service name
            service_name="$OPTARG"
            ;;
        f) # Service files folder
            service_folder="$OPTARG"
            ;;
        e) # Service exec path
            service_exec="$OPTARG"
            ;;
        s) # Run silently
            silent="$OPTARG"
            ;;
        h) # Display help
            Help
            exit;;
        \?) # Error for incorrect flags
            echo "Error: Invalid option"
            exit;;
        :) # Error for flags without arguments
            echo "Flag -$OPTARG requires an argument." >&2
            exit;;
    esac
done

none_interactive_flags=0
if [[ "$service_name" != "0"  || "$service_folder" != "0" ||  $service_exec != "0" ||  $silent != "0" ]]; then
    none_interactive_flags=1
fi

all_none_interactive_flags=0
if [[ "$service_name" != "0"  && "$service_folder" != "0"  &&  "$service_exec" != "0" &&  "$silent" != "0" ]]; then
    all_none_interactive_flags=1
fi

if [ $interactive_mode_flag -eq 1 ] && [ $none_interactive_flags -eq 0 ]; then
    get_cli_arguments
    main
elif [ $interactive_mode_flag -eq 0 ] && [ $all_none_interactive_flags -eq 1 ]; then
    check_flag_arguments
    main
elif [ $interactive_mode_flag -eq 1 ] && [ $none_interactive_flags -eq 1 ]; then
    echo "Flag -i cannot be used with flags -n,-f,-e,-s."
    exit
else
    echo "Invalid flags, try -h for help."
    exit
fi


            