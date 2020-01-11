# jackett_Dockerfile

Fork of <a href="https://github.com/triptixx/jackett">triptixx/jackett</a> docker image for the torznab proxy Jackett. Just have added auto generating sonfig file.

Link on docker hub: <a href="https://hub.docker.com/r/niiv0832/sslibev_serv">niiv0832/jackett</a>

Link on github: <a href="https://www.github.com/niiv0832/jackett_Dockerfile">niiv0832/jackett_Dockerfile</a>

## Usage

```shell
docker run -d --name=jackett --restart always --hostname=jackett -p 9117:9117 -v $YOUR_PATH_TO_JSON_CONFIG_DIR$:/config -t niiv0832/jackett
```

## Environment

- `$SUID`         - User ID to run as. _default: `921`_
- `$SGID`         - Group ID to run as. _default: `921`_
- `$TZ`           - Timezone. _optional_

## Volume

- `/config`       - Server configuration file location.

## Network

- `9117/tcp`      - WebUI.
