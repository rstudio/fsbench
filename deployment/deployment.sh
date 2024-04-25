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
R_VERSION="4.3.2"

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

detect_os

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
fi

cd $directory



# Continue with the script if choice is 'y' or anything else
echo "Continuing with the script..."
# Add your script logic here

if [ -f "/opt/R/${R_VERSION}/bin/R" ]; then
    echo "Selected version of R already installed at the expected path of /opt/R/${R_VERSION}/bin/R"
else
    # Prompt the user for yes/no input
    read -p "R version not found at /opt/R/${R_VERSION}/bin/R. Do you want to install R ${R_VERSION}? (y/n): " choice

    # Check if the choice is 'n', if so, exit the script
    if [[ $choice == [Nn] ]]; then
        echo "Exiting script."
        exit 1
    fi
    # Case statement to echo the combination of $os and $redhat_version if the OS is RedHat
    case $os in
        RedHat)
            case $redhat_version in
                9)
                  sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
                  sudo subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms
                  curl -O https://cdn.rstudio.com/r/rhel-9/pkgs/R-${R_VERSION}-1-1.x86_64.rpm
                  sudo dnf install -y R-${R_VERSION}-1-1.x86_64.rpm
                  ;;
                8)
                  sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
                  sudo subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms
                  curl -O https://cdn.rstudio.com/r/centos-8/pkgs/R-${R_VERSION}-1-1.x86_64.rpm
                  sudo yum install -y R-${R_VERSION}-1-1.x86_64.rpm
                  ;;
            esac
            ;;
        Ubuntu)
            sudo apt-get update
            sudo apt-get install gdebi-core
            case $ubuntu_version in
                  22)
                  curl -O https://cdn.rstudio.com/r/ubuntu-2204/pkgs/r-${R_VERSION}_1_amd64.deb
                  sudo gdebi -n r-${R_VERSION}_1_amd64.deb
                  ;;
                  20)
                  curl -O https://cdn.rstudio.com/r/ubuntu-2004/pkgs/r-${R_VERSION}_1_amd64.deb
                  sudo gdebi -n r-${R_VERSION}_1_amd64.deb
                  ;;
            esac

    esac
fi

echo "Verify R Installation"
R --version

echo "Adding R/Rscript to path"
export $PATH=/opt/R/${R_VERSION}/bin/

cd fsbench/

export TARGET_DIR=$directory

if [ -z "$OUTPUT_FILE" ]; then
    export OUTPUT_FILE="/opt"
fi

  # Prompt the user for yes/no input
read -p "Do you want to run the setup for fsbench? (y/n): " choice

# Check if the choice is 'n', if so, exit the script
if [[ $choice == [Nn] ]]; then
    echo "Exiting script."
    exit 1
fi

make setup

  # Prompt the user for yes/no input
read -p "Start fsbench run for storage mounted at ${directory} (y/n): " choice

# Check if the choice is 'n', if so, exit the script
if [[ $choice == [Nn] ]]; then
    echo "Exiting script."
    exit 1
fi

echo "Outputting log to directory ${OUTPUT_FILE}"

make

