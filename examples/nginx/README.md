# Example project for show casing Helm coordinates

See: [Helm Coordinates](https://github.com/irori-ab/helm-coord/)

## Example commands
git 
```
hc.sh environments/test/nginx-2 -e upgrade
hc.sh environments/test/nginx-1 -e upgrade
hc.sh environments/test/nginx-2 -e upgrade
hc.sh environments/test/nginx-1 -e upgrade

find environments -type d -mindepth 2 | xargs -I {} hc.sh {} -e diff upgrade
find environments -type d -mindepth 2 | xargs -I {} hc.sh {} -e upgrade
find environments -type d -mindepth 2 | xargs -I {} hc.sh {} -e uninstall
```