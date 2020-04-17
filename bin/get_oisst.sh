#!/bin/sh

umask 022

iy=$(date +'%Y') #current year
#iy_prev=$(date --date="$(date +%Y-%m-15) -1 month") #year of the previous month 
iy_prev=2019
machine=ftp.cdc.noaa.gov

dout=/local2/home/NMME/oisst_spear/raw

if [ ! -d ${dout} ]; then
  mkdir -p ${dout}
fi

cd $dout

if [[ ${iy} == ${iy_prev} ]]; then
echo "Downloading data for ${iy}"

ftp -n $machine << --          || exit
user anonymous Oar.Gfdl.Nmme@noaa.gov
cd Datasets/noaa.oisst.v2.highres
prompt
binary
mget icec.day.mean.${iy}.v2.nc
mget sst.day.mean.${iy}.v2.nc
quit
--

elif [[ ${iy} != ${iy_prev} ]]; then
echo "Downloading data for ${iy} and ${iy_prev}"

ftp -n $machine << --          || exit
user anonymous Oar.Gfdl.Nmme@noaa.gov
cd Datasets/noaa.oisst.v2.highres
prompt
binary
mget icec.day.mean.${iy}.v2.nc
mget sst.day.mean.${iy}.v2.nc
mget icec.day.mean.${iy_prev}.v2.nc
mget sst.day.mean.${iy_prev}.v2.nc
quit
--

fi
