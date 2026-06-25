FROM --platform=linux/amd64 ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install --no-install-recommends -y xfce4 xfce4-goodies tigervnc-standalone-server novnc websockify sudo xterm init systemd systemd-sysv snapd vim net-tools curl wget git tzdata
RUN apt update -y && apt install -y dbus-x11 x11-utils x11-xserver-utils x11-apps
RUN apt install software-properties-common -y
RUN add-apt-repository ppa:mozillateam/ppa -y
RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox
RUN echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox
RUN apt update -y && apt install -y firefox
RUN apt update -y && apt install -y xubuntu-icon-theme

# Full Ubuntu base package set on top of the xfce4 desktop
RUN apt update -y && apt install -y ubuntu-standard

RUN touch /root/.Xauthority

# Mask units that fail or hang under containerized systemd
RUN systemctl mask systemd-udevd.service systemd-udevd-kernel.socket \
    systemd-udevd-control.socket systemd-modules-load.service \
    sys-kernel-config.mount sys-kernel-debug.mount sys-fs-fuse-connections.mount \
    getty.target getty-static.service systemd-logind.service \
    systemd-remount-fs.service dev-hugepages.mount

EXPOSE 5901
EXPOSE 6080

# Write the startup script and the systemd unit inline, no extra files needed
RUN mkdir -p /opt/startup && \
    printf '%s\n' \
      '#!/bin/bash' \
      'set -e' \
      'su - root -c "vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE"' \
      'cd /opt/startup' \
      'openssl req -new -subj "/C=JP" -x509 -days 365 -nodes -out self.pem -keyout self.pem' \
      'websockify -D --web=/usr/share/novnc/ --cert=/opt/startup/self.pem 6080 localhost:5901' \
      > /opt/startup/start-vnc.sh && \
    chmod +x /opt/startup/start-vnc.sh

RUN printf '%s\n' \
      '[Unit]' \
      'Description=VNC + noVNC startup' \
      'After=multi-user.target' \
      '' \
      '[Service]' \
      'Type=oneshot' \
      'RemainAfterExit=yes' \
      'ExecStart=/opt/startup/start-vnc.sh' \
      '' \
      '[Install]' \
      'WantedBy=multi-user.target' \
      > /etc/systemd/system/vnc.service && \
    systemctl enable vnc.service

STOPSIGNAL SIGRTMIN+3

ENTRYPOINT ["/sbin/init"]
