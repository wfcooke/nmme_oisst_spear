#!/bin/sh

umask 022

iy=$(date +'%Y') #current year

iy_prev=$( date -d "$(date +%Y-%m-15) -1 month" +'%Y' ) #year of the previous month
mmyyyy=$( date -d "$(date +%Y-%m-15) -1 month" +'%Y%m' )
mm=$( date -d "$(date +%Y-%m-15) -1 month" +'%^b%Y' )
machine=ftp.cdc.noaa.gov

dout=/local2/home/NMME/oisst_spear/raw/${mm}

if [ ! -d ${dout} ]; then
  mkdir -p ${dout}
fi

#check to see if data has been processed yet
ok_file=/local2/home/NMME/oisst_spear/NetCDF/${mmyyyy}.OK

if [ -e ${ok_file} ]; then
    echo "${ok_file} exists, data already processed for this month."
    exit 0
else
    echo "${ok_file} does not exist, downloading raw data to ${dout}."
fi

#download data
cd $dout

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

echo "Finished downloading data"

