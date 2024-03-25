#!/bin/bash

detect_os() {
    if [ -f /etc/redhat-release ]; then
        redhat_version=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
        if [ "$redhat_version" == "8" ] || [ "$redhat_version" == "9" ]; then
            os="RedHat"
        fi
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" == "ubuntu" ]; then
            ubuntu_version=$(echo "$VERSION_ID" | cut -d. -f1)
            if [ "$ubuntu_version" == "20" ] || [ "$ubuntu_version" == "22" ]; then
                os="Ubuntu"
            fi
        fi
    fi
}

# Set the default directory name
default_directory="/opt"
r_version="4.3.2"

# Parse command line options
while getopts ":d:r:" opt; do
  case ${opt} in
    d )
      directory=$OPTARG
      ;;
    r )
      R_VERSION=$OPTARG
      ;;
    \? )
      echo "Usage: $(basename $0) [-d directory_name] [-r r_version]" >&2
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# If operating system not found or not in the specified list, exit
if [ -z "$os" ]; then
    echo "Operating system not supported."
    exit 1
fi

echo $os

# If directory is not provided as argument, use the default directory
if [ -z "$directory" ]; then
    directory="$default_directory"
fi

# Check if the directory exists
if [ ! -d "$directory" ]; then
    # Create the directory
    mkdir "$directory"
    echo "Directory '$directory' created."
else
    echo "Directory '$directory' already exists."
fi

cd $directory



#curl -O https://cdn.rstudio.com/r/ubuntu-2204/pkgs/r-${R_VERSION}_1_amd64.deb
#sudo gdebi -n r-${R_VERSION}_1_amd64.deb
#R --version
#git clone https://github.com/rstudio/fsbench
#cd fsbench/
#make setup
#make
