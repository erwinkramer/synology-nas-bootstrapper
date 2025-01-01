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
    "downloads"
    "config/synology"
    "config/qBittorrent"
    "config/jellyfin/cache"
    "config/jellyfin/config"
    "config/codeserver"
    "config/postgres/data"
    "config/postgres/scripts"
    "config/caddy"
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

echo "setting .env file variables uid to '$userid', gid to '$groupid' and vgid to '$videodrivergroupid'..."

touch $envfiledockercompose
if grep -q "^uid=" $envfiledockercompose; then
    sed -i "/^uid=/c\uid=$userid $modifiedonbycomment" $envfiledockercompose
else
    echo "uid=$userid $modifiedonbycomment" >> $envfiledockercompose
fi

if grep -q "^gid=" $envfiledockercompose; then
    sed -i "/^gid=/c\gid=$groupid $modifiedonbycomment" $envfiledockercompose
else
    echo "gid=$groupid $modifiedonbycomment" >> $envfiledockercompose
fi

if grep -q "^vgid=" $envfiledockercompose; then
    sed -i "/^vgid=/c\vgid=$videodrivergroupid $modifiedonbycomment" $envfiledockercompose
else
    echo "vgid=$videodrivergroupid $modifiedonbycomment" >> $envfiledockercompose
fi

echo "script done"
