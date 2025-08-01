#!/bin/bash

: '

Create the user, group and shared folder structure with permissions for users and groups. 
Modifies the .env file for docker compose (or creates if not exists) with the uid and gid of the user and group created.

Called from main.sh

'

groupnamedocker=$1
usernamedocker="dockerlimited"
email="info@guanchen.nl"
currentdatetime=$(date '+%d-%m-%Y %H:%M:%S')
modifiedonbycomment="# automatically modified by 'filesystem.sh' script on $currentdatetime"
sharedockername="docker"
sharedataname="data"
volume=/volume1
envfiledockercompose="$volume/$sharedockername/projects/garden/.env"

dockerfolders=(
    "projects/garden"
)

datafolders=(
    "media/movies"
    "media/images"
    "downloads"
    "config/synology"
    "config/qBittorrent"
    "config/jellyfin/cache"
    "config/jellyfin/config"
    "config/codeserver"
    "config/postgres/data"
    "config/postgres/scripts"
    "config/caddy"
    "config/coredns"
    "config/radarr"
    "config/prowlarr"
    "config/bazarr"
    "config/windows"
)

declare -A user_credentials=(
    [$usernamedocker]=$(openssl rand -base64 12)
    ["tv"]="tv"
)

declare -A user_descriptions=(
    [$usernamedocker]="Docker Account"
    ["tv"]="TV Account"
)

declare -A group_users=(
    [$groupnamedocker]=$usernamedocker
)

declare -A share_permittedreadwritegroups=(
    [$sharedockername]="$groupnamedocker"
    [$sharedataname]="$groupnamedocker"
)

declare -A share_permittedreadobjects=(
    ["tv"]="tv"
)

echo "creating the user structure..."

for username in "${!user_credentials[@]}"; do
    password=${user_credentials[$username]}
    description=${user_descriptions[$username]}

    if ! synouser --get $username >/dev/null 2>&1; then
        echo "setting user $username with password $password, it might be wise to tick 'Disallow the user to change account password' in the portal for accounts with non-random passwords..."
        synouser --add "$username" "$password" "$description" 0 "$email" 0
    else
        echo "user '$username' already exists"
    fi
done

echo "creating the group and members structure..."

for group in "${!group_users[@]}"; do
    users=${group_users[$group]}

    if ! synogroup --get $group >/dev/null 2>&1; then
        echo "setting group $group with members..."
        synogroup --add "$group" "$users"
    else
        echo "group '$group' already exists, correcting members..."
        synogroup --member "$group" "$users"
    fi
done

echo "creating the share structure..."

for sharename in "${!share_permittedreadwritegroups[@]}" "${!share_permittedreadobjects[@]}"; do
    if [[ -n ${share_permittedreadwritegroups[$sharename]} ]]; then
        permittedobject="@${share_permittedreadwritegroups[$sharename]}"
        permission="RW"
    elif [[ -n ${share_permittedreadobjects[$sharename]} ]]; then
        permittedobject=${share_permittedreadobjects[$sharename]}
        permission="RO"
    fi

    if ! synoshare --get $sharename >/dev/null 2>&1; then
        echo "setting share $sharename..."
        synoshare --add "$sharename" "${sharename^} folder" "$volume/$sharename" "" "" "" 1 0
    else
        echo "share '$sharename' already exists"
    fi

    echo "setting share permission on $sharename for user or group $permittedobject with $permission access..."
    if ! synoshare --setuser "$sharename" $permission + "$permittedobject" >/dev/null 2>&1; then
        echo "Error setting share permission on $sharename for user or group $permittedobject"
    fi
done

echo "creating the data folder structure..."

for folder in "${datafolders[@]}"; do
    folderpath="$volume/$sharedataname/$folder"
    mkdir -p $folderpath

    echo "giving ownership of all folders and files under $folderpath to $usernamedocker user and $groupnamedocker group..."
    chown -R "$usernamedocker:$groupnamedocker" $folderpath
done

echo "creating the docker folder structure..."

for folder in "${dockerfolders[@]}"; do
    folderpath="$volume/$sharedockername/$folder"
    mkdir -p $folderpath
done

echo "preparing the .env file variables..."

userid=$(synouser --get $usernamedocker | awk -F "[][{}]" '/User uid/ { print $2 }')
groupid=$(synogroup --get $groupnamedocker | awk -F "[][{}]" '/Group ID/ { print $2 }')
videodrivergroupid=$(id -g videodriver)

hostip=$(ip route get 1 | awk '{print $NF;exit}')

default_interface=$(ip route | awk '/default/ {print $5}' | head -n1)
hostrange=$(ip -o -f inet addr show "$default_interface" | awk '{print $4}' | sed 's/\.[0-9]\+\//.0\//')

timezone=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')

# Wait for Docker to be available and get the client API version
while ! dockerversion=$(docker version --format '{{.Client.APIVersion}}' 2>/dev/null); do
    echo "waiting for Docker to be available..."
    sleep 1
done

echo "setting .env file variables..."
touch $envfiledockercompose

declare -A env_vars=(
    ["uid"]=$userid
    ["gid"]=$groupid
    ["vgid"]=$videodrivergroupid
    ["private_ip"]=$hostip
    ["private_ip_range"]=$hostrange
    ["timezone"]=$timezone
    ["docker_api_version"]=$dockerversion
    ["nas_name"]=$(hostname)
)

for var in "${!env_vars[@]}"; do
    echo "setting $var=${env_vars[$var]}"

    if grep -q "^$var=" $envfiledockercompose; then
        sed -i "/^$var=/c\\$var=${env_vars[$var]} $modifiedonbycomment" $envfiledockercompose
    else
        echo "$var=${env_vars[$var]} $modifiedonbycomment" >>$envfiledockercompose
    fi
done

echo "filesystem script done"
