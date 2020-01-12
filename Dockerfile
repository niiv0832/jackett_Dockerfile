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

COPY *.sh /output/usr/local/bin/
RUN chmod -R u=rwX,go=rX /output/jackett; \
    chmod +x /output/usr/local/bin/*.sh /output/jackett/jackett

#=============================================================

FROM loxoo/alpine:${ALPINE_TAG}

ARG JACKETT_VER
ENV SUID=921 SGID=921

LABEL org.label-schema.name="jackett" \
      org.label-schema.description="A docker image for the torznab proxy Jackett" \
      org.label-schema.url="https://github.com/Jackett/Jackett" \
      org.label-schema.version=${JACKETT_VER}

COPY --from=builder /output/ /

RUN apk add --no-cache libstdc++ \
                       libgcc \
                       libintl \ 
                       icu-libs && \
   mkdir /config && \
   touch /tmp/ServerConfig.json && \
   echo "{" > /tmp/ServerConfig.json && \
   echo '  "Port": 9117,' >> /tmp/ServerConfig.json && \
   echo '  "AllowExternal": true,' >> /tmp/ServerConfig.json && \
   echo '  "APIKey": "<apikey>",' >> /tmp/ServerConfig.json && \
   echo '  "AdminPassword": null,' >> /tmp/ServerConfig.json && \
   echo '  "InstanceId": "<instanceid>",' >> /tmp/ServerConfig.json && \
   echo '  "BlackholeDir": null,' >> /tmp/ServerConfig.json && \
   echo '  "UpdateDisabled": true,' >> /tmp/ServerConfig.json && \
   echo '  "UpdatePrerelease": false' >> /tmp/ServerConfig.json && \
   echo "}" >> /tmp/ServerConfig.json && \
   
#   export APIKEY=${APIKEY-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)} && \
#   export INSTANCEID=${INSTANCEID-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 100 | head -n 1)} &&\
#   sed 's/<apikey>/'${APIKEY}'/;s/<instanceid>/'${INSTANCEID}'/' /tmp/ServerConfig.json > /config/ServerConfig.json && \
   chmod -R u=rwX,go=rwX /config && \
#   rm -rf /tmp/* 

VOLUME /config

EXPOSE 9117/TCP

HEALTHCHECK --start-period=10s --timeout=5s \
    CMD wget -qO /dev/null "http://localhost:9117/torznab/all"

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["/jackett/jackett", "-x", "-d", "/config", "--NoUpdates"]
