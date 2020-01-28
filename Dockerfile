ARG ALPINE_TAG=3.11
ARG DOTNET_TAG=3.1
ARG JACKETT_VER=0.12.1539

FROM mcr.microsoft.com/dotnet/core/sdk:${DOTNET_TAG}-alpine AS builder

ARG JACKETT_VER
ARG DOTNET_TAG

### install jackett
WORKDIR /jackett-src
RUN apk add --no-cache git jq binutils file; \
    COMMITID=$(wget -q -O- https://ci.appveyor.com/api/projects/Jackett/jackett/build/${JACKETT_VER} \
        | jq -r '.build.commitId'); \
    git clone https://github.com/Jackett/Jackett.git .; \
    git checkout $COMMITID; \
    dotnet publish -p:Version=${JACKETT_VER} -p:PublishTrimmed=true -c Release -f netcoreapp${DOTNET_TAG} \
        -r linux-musl-x64 -o /output/jackett src/Jackett.Server; \
    find /output/jackett -exec sh -c 'file "{}" | grep -q ELF && strip --strip-debug "{}"' \;

RUN chmod -R u=rwX,go=rX /output/jackett; \
    chmod +x /output/jackett/jackett

#=============================================================

FROM loxoo/alpine:${ALPINE_TAG}

ARG JACKETT_VER
ENV SUID=921 SGID=921

LABEL org.label-schema.name="jackett" \
      org.label-schema.description="A docker image for the torznab proxy Jackett" \
      org.label-schema.url="https://github.com/Jackett/Jackett" \
      org.label-schema.version=${JACKETT_VER}

COPY --from=builder /output/ /

RUN apk add --no-cache --update \
                                libstdc++ \
                                libgcc \
                                libintl \ 
                                icu-libs && \
   rm -rf /var/cache/apk/* && \
### create ServerConfig.json template
   touch /tmp/ServerConfig.json && \
   echo '{' > /tmp/ServerConfig.json && \
   echo '  "Port": 9117,' >> /tmp/ServerConfig.json && \
   echo '  "AllowExternal": true,' >> /tmp/ServerConfig.json && \
   echo '  "APIKey": "<apikey>",' >> /tmp/ServerConfig.json && \
   echo '  "AdminPassword": null,' >> /tmp/ServerConfig.json && \
   echo '  "InstanceId": "<instanceid>",' >> /tmp/ServerConfig.json && \
   echo '  "BlackholeDir": null,' >> /tmp/ServerConfig.json && \
   echo '  "UpdateDisabled": true,' >> /tmp/ServerConfig.json && \
   echo '  "UpdatePrerelease": false' >> /tmp/ServerConfig.json && \
   echo '}' >> /tmp/ServerConfig.json && \
### create entrypoint.sh
   mkdir -p /usr/local/bin/ && \
   touch /usr/local/bin/entrypoint.sh && \
   echo '#!/bin/sh' > /usr/local/bin/entrypoint.sh && \
   echo 'APIKEY=${APIKEY-$(cat /dev/urandom | tr -dc "a-zA-Z0-9" | fold -w 32 | head -n 1)}' >> /usr/local/bin/entrypoint.sh && \
   echo 'INSTANCEID=${INSTANCEID-$(cat /dev/urandom | tr -dc "a-zA-Z0-9" | fold -w 100 | head -n 1)}' >> /usr/local/bin/entrypoint.sh && \
   echo 'if [ ! -e /config/ServerConfig.json ]; then' >> /usr/local/bin/entrypoint.sh && \
   echo '	sed "s/<apikey>/"${APIKEY}"/;s/<instanceid>/"${INSTANCEID}"/" /tmp/ServerConfig.json > /config/ServerConfig.json' >> /usr/local/bin/entrypoint.sh && \
   echo '	chmod -R u=rwX,go=rwX /config' >> /usr/local/bin/entrypoint.sh && \
   echo 'fi' >> /usr/local/bin/entrypoint.sh && \
   echo '        rm -rf /tmp/*' >> /usr/local/bin/entrypoint.sh && \
   echo '' >> /usr/local/bin/entrypoint.sh && \
   echo 'set -eo pipefail' >> /usr/local/bin/entrypoint.sh && \
   echo '# ANSI colour escape sequences' >> /usr/local/bin/entrypoint.sh && \
   echo "RED='\033[0;31m'" >> /usr/local/bin/entrypoint.sh && \
   echo "RESET='\033[0m'" >> /usr/local/bin/entrypoint.sh && \
   echo '' >> /usr/local/bin/entrypoint.sh && \
   echo "CONFIG_DIR='/config'" >> /usr/local/bin/entrypoint.sh && \
   echo '' >> /usr/local/bin/entrypoint.sh && \
   echo 'if su-exec $SUID:$SGID [ ! -w "$CONFIG_DIR" ]; then' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo -e "${RED}####################### WARNING #######################${RESET}"' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo -e "${RED}     No permission to write in "$CONFIG_DIR" directory.${RESET}"' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo -e "${RED}       Correcting permissions to prevent a crash.${RESET}"' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo -e "${RED}#######################################################${RESET}"' >> /usr/local/bin/entrypoint.sh && \
   echo '    2>&1 echo' >> /usr/local/bin/entrypoint.sh && \
   echo '' >> /usr/local/bin/entrypoint.sh && \
   echo '    chown $SUID:$SGID "$CONFIG_DIR"' >> /usr/local/bin/entrypoint.sh && \
   echo 'fi' >> /usr/local/bin/entrypoint.sh && \
   echo '' >> /usr/local/bin/entrypoint.sh && \
   echo 'exec su-exec $SUID:$SGID "$@"' >> /usr/local/bin/entrypoint.sh && \
   chmod +x /usr/local/bin/entrypoint.sh && \
### create /config dir
   mkdir /config && \
   chmod -R u=rwX,go=rwX /config
   
EXPOSE 9117/TCP

HEALTHCHECK --start-period=10s --timeout=5s \
    CMD wget -qO /dev/null "http://localhost:9117/torznab/all"

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/jackett/jackett", "-x", "-d", "/config", "--NoUpdates"]
