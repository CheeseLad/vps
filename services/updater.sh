#!/bin/bash

# pull any new images and
# recreate the containers if a new image is pulled

now=$(date +"%Y-%m-%d %T")
printf "%s\n---\n" "$now"
for dir in /home/debian/services/*; do 
    if [[ -d "$dir" && "${dir}" != *"disabled"* ]]; then
         cd "$dir" || continue
        /usr/bin/docker compose pull
        /usr/bin/docker compose up -d
        cd ..
    fi
done

docker image prune -f
echo
