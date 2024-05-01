#!/bin/bash

set -e

echoerr() { echo "$@" 1>&2; }

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

# Function to prompt the user for yes/no input
ask_question() {
    local question="$1"
    read -p "$question (y/n): " choice
    # Convert choice to lowercase for comparison
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    # Check if the choice is valid
    if [[ "$choice_lower" == "y" ]]; then
        return 0  # Return success (true)
    elif [[ "$choice_lower" == "n" ]]; then
        return 1  # Return failure (false)
    else
        echoerr "Please enter either 'y' or 'n'."
        ask_question "$question"  # Ask the question again
    fi
}


# Set the default directory name
default_directory="/opt"
R_VERSION="4.4.0"

# Get cloned repo location on disk
current_dir="$(dirname "$(readlink -f "$0")")"

echoerr "Deployment script running from: $current_dir/deployment.sh"


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
      echoerr "Usage: $(basename $0) [-d directory_name] [-r r_version]" >&2
      exit 1
      ;;
    : )
      echoerr "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

detect_os

# If operating system not found or not in the specified list, exit
if [ -z "$os" ]; then
    echoerr "Operating system not supported."
    exit 1
fi

echoerr $os

# If directory is not provided as argument, use the default directory
if [ -z "$directory" ]; then
    directory="$default_directory"
fi

# Check if the directory exists
if [ ! -d "$directory" ]; then
    # Create the directory
    mkdir "$directory"
    echoerr "Directory '$directory' created."
fi


# Continue with the script if choice is 'y' or anything else

if [ -f "/opt/R/${R_VERSION}/bin/R" ]; then
    echoerr "Selected version of R already installed at the expected path of /opt/R/${R_VERSION}/bin/R"
else
    # Prompt the user for yes/no input
    read -p "R version not found at /opt/R/${R_VERSION}/bin/R. Do you want to install R ${R_VERSION}? (y/n): " choice

    # Check if the choice is 'n', if so, exit the script
    if [[ $choice == [Nn] ]]; then
        echoerr "Exiting script."
        exit 1
    fi
    # Case statement to echo the combination of $os and $redhat_version if the OS is RedHat
    case $os in
        RedHat)
            case $redhat_version in
                9)
                  sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
                  # Prompt the user for yes/no input
                  ask_question "Is this Linux instance running in a Public Cloud? (AWS, Azure, GCP, etc)"
                  # Check if the choice is 'n', if so, exit the script
                  if [[ $choice == [Nn] ]]; then
                    sudo subscription-manager repos --enable codeready-builder-for-rhel-9-${arch}-rpms
                  elif [[ $choice == [Yy] ]]; then
                    sudo dnf install dnf-plugins-core
                    sudo dnf config-manager --set-enabled codeready-builder-for-rhel-9-*-rpms
                  fi
                  curl -O https://cdn.rstudio.com/r/rhel-9/pkgs/R-${R_VERSION}-1-1.x86_64.rpm
                  dnf remove -y R-${R_VERSION}-1-1.x86_64
                  dnf install -y R-${R_VERSION}-1-1.x86_64.rpm
                  ;;
                8)
                  sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
                  ask_question "Is this Linux instance running in a Public Cloud? (AWS, Azure, GCP, etc)"
                  # Check if the choice is 'n', if so, exit the script
                  if [[ $choice == [Nn] ]]; then
                    sudo subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms
                  elif [[ $choice == [Yy] ]]; then
                    sudo dnf install dnf-plugins-core
                    sudo dnf config-manager --set-enabled "codeready-builder-for-rhel-8-*-rpms"
                  fi
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
    touch R-installed-by-script
fi

echoerr "Adding R/Rscript to path"
export PATH=/opt/R/${R_VERSION}/bin/:$PATH
echoerr "Process PATH: ${PATH}"

echoerr "Verify R Installation"
R --version


export TARGET_DIR=$directory
echoerr "Set target directory to ${TARGET_DIR}"

if [ -z "$OUTPUT_FILE" ]; then
    export OUTPUT_FILE="/opt"
fi

#Change location to Makefile location too avoid relative path issues
cd $current_dir/..

ask_question "Do you want to run the setup for fsbench?"

# Check if the choice is 'n', if so, exit the script
if [[ $choice == [Nn] ]]; then
    echoerr "Exiting script."
    exit 1
fi


make setup

  # Prompt the user for yes/no input
ask_question "Start fsbench run for storage mounted at ${directory}?"

# Check if the choice is 'n', if so, exit the script
if [[ $choice == [Nn] ]]; then
    echoerr "Exiting script."
    exit 1
fi

echoerr "Outputting log to directory ${OUTPUT_FILE}"

make

echoerr "fsbench has completed it's run on ${OUTPUT_FILE}"

if [ -f "${current_dir}/R-installed-by-script" ]; then
  # Prompt the user for yes/no input
  ask_question "Do you want to remove R ${R_VERSION}?"

  # Check if the choice is 'n', if so, exit the script
  if [[ $choice == [Nn] ]]; then
      echoerr "Exiting script."
      exit 1
  fi

  case $os in
      RedHat)
          case $redhat_version in
              9)
                sudo dnf remove -y R-${R_VERSION}-1-1.x86_64
                ;;
              8)
                sudo yum remove -y R-${R_VERSION}-1-1.x86_64
                ;;
          esac
          ;;
      Ubuntu)
          case $ubuntu_version in
                22)
                sudo apt remove r-${R_VERSION}
                ;;
                20)
                sudo apt remove r-${R_VERSION}
                ;;
          esac

  esac
fi



