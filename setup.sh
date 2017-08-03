#!/usr/bin/env bash

#######################
#  Dependency Checks  #
#######################

# Function to check if referenced command exists
cmd_exists() {
  if [ $# -eq 0 ]; then
    echo 'WARNING: No command argument was passed to verify exists'
  fi

  #cmds=($(echo "${1}"))
  cmds=($(printf '%s' "${1}"))
  fail_counter=0
  for cmd in "${cmds[@]}"; do
    command -v "${cmd}" >&/dev/null # portable 'which'
    rc=$?
    if [ "${rc}" != "0" ]; then
      fail_counter=$((fail_counter+1))
    fi
  done

  if [ "${fail_counter}" -ge "${#cmds[@]}" ]; then
    echo "Unable to find one of the required commands [${cmds[*]}] in your PATH"
    return 1
  fi
}

manage_keys() {
  if [ -d .keys ]; then
    echo "Already found a .keys dir"
  else
    echo "Making a .keys dir for keys"
    mkdir .keys
  fi
  echo "Checking for private key"
  if [ -f .keys/swarm_key ] && [ -f .keys/swarm_key.pub ]; then
    echo "Keys already present. Skipping."
    echo "Don't forget to add the key to ssh-agent!!"
    return 0
  else
    echo "No keys found, creating.."
    ssh-keygen -t rsa -b 4096 -C "RaspberryPi Swarm SSH Key" -N "" -f .keys/swarm_key -q
    if [ $? -ne 0 ]; then
      echo "Something went wrong while trying to create keys"
      echo "Bailing out"
      exit 1
    fi
  fi
  prgrep ssh-agent > /dev/null
  if [ $? -ne 0 ]; then
    echo "No ssh-agent running. Starting"
    eval `ssh-agent`
  else
    echo "ssh-agent appears to be running"
  fi
  ssh-add -l | grep .keys/swarm_key > /dev/null
  if [ $? -ne 0 ]; then
    echo "swarm_key not found in agent. Adding"
    ssh-add .keys/swarm_key
  else
    echo "swarm_key appears to already be present. Skipping add"
  fi
}

DEP_PKGS="build-essential libssl-dev libffi-dev python-dev python-setuptools python-cffi sshpass"
check_depends() {
  dpkg -l $DEP_PKGS
  if [ $? -ne 0 ]; then
    echo "At least some dependencies not found"
    echo "Installing $DEP_PKGS"
    sudo apt-get update && sudo apt-get install -y $DEP_PKGS
    if [ $? -ne 0 ]; then
      echo "Something went wrong installing. Bailing out"
      exit 1
    else
      echo "apt dependencies installed successfully."
    fi
  else
    echo "All apt dependencies present"
  fi
}
  
check_depends
if [ $? -ne 0 ]; then
  echo "Something went wrong installing dependencies"
  exit 1
fi

pip_cmd_list=('pip')
for cmd in "${pip_cmd_list[@]}"; do
  cmd_exists "${cmd[@]}"
  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "Installing Python PIP via Easy_Install"
    sudo easy_install pip
  fi
done

virtenv_cmd_list=(
  'virtualenv virtualenv-2.7 virtualenv-2.5'
)
for cmd in "${virtenv_cmd_list[@]}"; do
  cmd_exists "${cmd[@]}"
  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "Installing Python virtualenv via PIP"
    sudo pip install virtualenv
  fi
done

#######################
#  Library Functions  #
#######################

run() {
    "$@"
    rc=$?
    if [[ $rc -gt 0 ]]; then
        return $rc
    fi
}

#######################
echo " -------------------------------------------------------------------"
echo "|                                                                   |"
echo "| You should be running this with "source ./setup.sh"               |"
echo "| Running this directly like:                                       |"
echo "| * ./setup.sh                                                      |"
echo "| * bash ./setup.sh                                                 |"
echo "| Will fail to set certain environment variables that may bite you. |"
echo "|                                                                   |"
echo "|                                                                   |"
echo "| Waiting 5 seconds for you make sure you have ran this correctly   |"
echo "| Cntrl-C to bail out...                                            |"
echo "|                                                                   |"
echo " -------------------------------------------------------------------"

for n in {5..1}; do
  printf "\r%s " $n
  sleep 1
done

if [ ! -d ./.venv ]; then
    echo "Failed to find a virtualenv, creating one."
    run virtualenv ./.venv
else
    echo "Found existing virtualenv, using that instead."
fi

# Planned feature to roll out ssh keys
# Ansible is literally the worst when it comes
# to authentication management.
# How are you supposed to SSH to 1000000 hosts
# change your password
# then reauthenticate to all of them!
# run manage_keys

. ./.venv/bin/activate
run pip install --upgrade pip
run pip install --upgrade setuptools
run pip install -r requirements.txt
# Uncomment the following line if using ansible-galaxy roles
#run ansible-galaxy install -r requirements.yml -p galaxy_roles -f

echo " ----------------------------------------------------------------------------"
echo "|                                                                            |"
echo "| You are now within a python virtualenv at ./.venv                          |"
echo "| This means that all python packages installed will not affect your system. |"
echo "| To return _back_ to system python, run deactivate in your shell.           |"
echo "|                                                                            |"
echo " ----------------------------------------------------------------------------"
