: '

Create the user, group and shared folder structure with permissions for Docker. 
Modifies the .env file for docker compose (or creates if not exists) with the uid and gid of the user and group created.

Control Panel > Task Scheduler > Create > Triggered Task > User-defined script. 

Set User to 'root' and leave the Event as 'Boot-up',
go to Task Settings and paste the following in User-defined script:

bash /volume1/docker/projects/garden/tasks/filesystem.sh

'

sharedockerfoldername=docker
shareddatafoldername=data
volume=/volume1
envfiledockercompose="$volume/$sharedockerfoldername/projects/garden/.env"
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
)

groupname="dockergroup"
username="dockerlimited"
email="info@guanchen.nl"
password=$(openssl rand -base64 12)

currentdatetime=$(date '+%d-%m-%Y %H:%M:%S')
modifiedonbycomment="# automatically modified by 'filesystem.sh' script on $currentdatetime"

echo "creating the data folder structure..."

for folder in "${datafolders[@]}"; do
    mkdir -p "$volume/$shareddatafoldername/$folder"
done

echo "creating the docker folder structure..."

for folder in "${dockerfolders[@]}"; do
    mkdir -p "$volume/$sharedockerfoldername/$folder"
done

if ! synouser --get $username; then
    echo "setting user $username with random password $password..."
    synouser --add "$username" "$password" "Docker Account" 0 "$email" 0
else
    echo "user '$username' already exists"
fi

if ! synogroup --get $groupname; then
    echo "setting group $groupname..."
    synogroup --add "$groupname" "$username"
else
    echo "group '$groupname' already exists"
fi

for sharename in $shareddatafoldername $sharedockerfoldername; do
    if ! synoshare --get $sharename; then
        echo "setting share $sharename..."
        synoshare --add "$sharename" "${sharename^} folder" "$volume/$sharename" "" "" "" 1 0
        synoshare --setuser "$sharename" RW + "@$groupname"
    else
        echo "share '$sharename' already exists"
    fi
done

userid=$(synouser --get $username | awk -F "[][{}]" '/User uid/ { print $2 }')
groupid=$(synogroup --get $groupname | awk -F "[][{}]" '/Group ID/ { print $2 }')
videodrivergroupid=$(id -g videodriver)

hostip=$(ip route get 1 | awk '{print $NF;exit}')
hostrange=$(ip -o -f inet addr show eth0 | awk '{print $4}' | sed 's/\.[0-9]\+\//.0\//')

timezone=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')

echo "setting .env file variables..."
touch $envfiledockercompose

declare -A env_vars=(
    ["uid"]=$userid
    ["gid"]=$groupid
    ["vgid"]=$videodrivergroupid
    ["private_ip"]=$hostip
    ["private_ip_range"]=$hostrange
    ["timezone"]=$timezone
)

for var in "${!env_vars[@]}"; do
    echo "setting $var=${env_vars[$var]}"

    if grep -q "^$var=" $envfiledockercompose; then
        sed -i "/^$var=/c\\$var=${env_vars[$var]} $modifiedonbycomment" $envfiledockercompose
    else
        echo "$var=${env_vars[$var]} $modifiedonbycomment" >> $envfiledockercompose
    fi
done

echo "script done"
