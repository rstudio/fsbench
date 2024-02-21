#!/bin/bash
rm -rf /opt/fsbench/*
rm -rf /root/.cache/
mkdir -p /opt/fsbench/
cd /opt/fsbench
export R_VERSION=4.3.2
curl -O https://cdn.rstudio.com/r/ubuntu-2204/pkgs/r-${R_VERSION}_1_amd64.deb
sudo gdebi -n r-${R_VERSION}_1_amd64.deb
R --version
git clone https://github.com/samcofer/fsbench
cd fsbench/
make setup
make
