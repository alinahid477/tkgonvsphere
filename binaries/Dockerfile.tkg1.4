FROM debian:buster-slim


ENV DOCKER_VERSION=20.10.8
ENV TANZU_CLI_VERSION=1.4.0


# culr (optional) for downloading/browsing stuff
# openssh-client (required) for creating ssh tunnel
# psmisc (optional) I needed it to test port binding after ssh tunnel (eg: netstat -ntlp | grep 6443)
# nano (required) buster-slim doesn't even have less. so I needed an editor to view/edit file (eg: /etc/hosts) 
# jq for parsing json (output of az commands, kubectl output etc)
# unzip needed 
# dante - dante client provide socksify command;
# connect.c - classic solution to ssh through proxy (socks and http) with authentication capabilities;
# nc (netcat) and socat - same but with no proxy authentication;
# sshuttle - "vpn" solution, route TCP traffic through ssh connection;
# sshpass - ssh password authentication (octopus does not accept ssh keys)
RUN apt-get update && apt-get install -y \
	apt-transport-https \
	ca-certificates \
	curl \
	unzip \
	&& curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
	&& chmod +x /usr/local/bin/kubectl


# RUN curl -o /usr/local/bin/jq -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
#   	chmod +x /usr/local/bin/jq


RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz \
  && tar xzvf docker-${DOCKER_VERSION}.tgz --strip 1 \
                 -C /usr/local/bin docker/docker \
  && rm docker-${DOCKER_VERSION}.tgz


COPY binaries/tanzu-cli-bundle-linux-amd64.tar /tmp/
RUN cd /tmp && mkdir tanzu \
	&& tar -xvf tanzu-cli-bundle-linux-amd64.tar -C tanzu/ \
	&& cd /tmp/tanzu/cli \
	&& install core/v${TANZU_CLI_VERSION}/tanzu-core-linux_amd64 /usr/local/bin/tanzu \
	&& cd /tmp/tanzu \
	&& tanzu plugin clean

COPY binaries/bastionhostinit.sh /usr/local/bastionhostinit.sh
RUN chmod +x /usr/local/bastionhostinit.sh

# COPY binaries/tmc /usr/local/bin/
# RUN chmod +x /usr/local/bin/tmc


# ARG USER_ID
# ARG GROUP_ID

# RUN addgroup --gid $GROUP_ID user
# RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
# USER user

ENTRYPOINT [ "/usr/local/bastionhostinit.sh"]