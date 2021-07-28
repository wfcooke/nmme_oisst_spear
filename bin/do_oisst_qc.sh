#!/bin/sh -xe

echoerr() {
    echo "$@" 1>&2
}

# Set the umask for world readable
umask 022

# Check limits
ulimit -a

# Location of this script
BIN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default settings for year/month
# Need everything for Dec 31 of the previous year up the the first of the current month
# That is, we need to process ${yearPrev}1231 - ${yearCur}${monCur}01.
yearCur=$( date '+%Y' )
monCur=$( date '+%m' )

# Source the env.sh file for the current environment, or exit if it doesn't exit.
if [[ ! -e ${BIN_DIR}/env.sh ]]; then
    echoerr "ERROR: Environment script '${BIN_DIR}/env.sh' doesn't exits."
    exit 1
fi
. ${BIN_DIR}/env.sh

# Useful PATHS
DATA_DIR=$( dirname ${BIN_DIR} )/data

# Check for the existance of the work and raw data directories
if [[ -z ${RAW_DIR} ]]; then
    echoerr "The variable RAW_DATA needs to be set in the configuration file ${BIN_DIR}/env.sh."
    exit 1
fi

#set up monthly raw dir
MONYYYY=$( date -d "$(date +%Y-%m-15) -1 month" +'%^b%Y' )

RAW_DIR_MM=${RAW_DIR}/${MONYYYY}

if [[ ! -e ${RAW_DIR_MM} ]]; then
    echoerr "Raw data not available"
    exit 1
fi

# Create the output directory
if [[ -z ${OUT_DIR} ]]; then
    echoerr "The variable OUT_DIR needs to be set in the configuration file ${BIN_DIR}/env.sh."
    exit 1
elif [ ! -e ${OUT_DIR} ]; then
    mkdir -p ${OUT_DIR}
fi

# Verify the WORK_DIR is set
if [[ -z ${WORK_DIR} ]]; then
    echoerr "The variable WORK_DIR needs to be set in the configuration file ${BIN_DIR}/env.sh."
    exit 1
fi

# Remove old work directory, and recreate.
if [ -e ${WORK_DIR} ]; then
    rm -rf ${WORK_DIR}
fi
mkdir -p ${WORK_DIR}

# Verify the output directory exists
if [ ! -e ${OUT_DIR} ]; then
    mkdir -p ${OUT_DIR}
fi

# Get the year and month for current date - 1month
yearPrev=$( date -d "${yearCur}-${monCur}-01 - 1year" '+%Y' )

# Special case for January
if [[ ${monCur} == 01 ]]; then
    #set yearPrev to yearPrev-1
    yearPrev=$(( $yearPrev -1 ))
fi

# Get the year and month for the last month for OK file
last_yearmon=$( date -d "$(date +%Y-%m-15) -1 month" +'%Y%m' )
last_year=$( date -d "$(date +%Y-%m-15) -1 month" +'%Y' )

# Convert the start/end Dates  to d-mmm-yyyy and yymmdd
firstDate="${yearPrev}-12-31"
lastDate="${yearCur}-${monCur}-01"
sDate=$( date -d $firstDate '+%-d-%b-%Y' )
eDate=$( date -d $lastDate '+%-d-%b-%Y' )
e_yyyymmdd=$( date -d $lastDate '+%Y-%m-%d' )

# Output file
sst_spear=sst_oidaily_icecorr_icec25_${last_year}01_${last_yearmon}.nc

if [[ -z $OUTFILE ]]; then
    # Set the default OUTFILE if not set by option above
    OUTFILE=${OUT_DIR}/${sst_spear}
fi

# Check if the output file exists. If it exists, exit.
OKFILE=${OUT_DIR}/${last_yearmon}.OK
if [[ -e ${OKFILE} ]]; then
    echoerr "File '${OKFILE}' already exists.  Not processing."
    exit 0
fi

# Begin actual work, need to be in WORK_DIR
cd ${WORK_DIR}

    inFile_sst="${RAW_DIR_MM}/sst.day.mean.${last_year}.v2.nc"
    inFile_ice="${RAW_DIR_MM}/icec.day.mean.${last_year}.v2.nc"
if [[ ! -e ${inFile_sst} || ! -e ${inFile_ice} ]]; then
    echoerr "ERROR: Unable to find raw data file file for ${last_year}-${m}-${d}"
    exit 1 
fi                    

#check that the first of the current month is in the files
if [[ ${monCur} == 01 ]]; then
    cdo seldate,${e_yyyymmdd} ${RAW_DIR_MM}/sst.day.mean.${yearCur}.v2.nc out.nc
else
    cdo seldate,${e_yyyymmdd} ${inFile_sst} out.nc
fi

#check to see if data for date is missing
gridsize=$( echo `cdo infon out.nc` | awk '{split($0,a," "); print a[20]}' )
missing=$( echo `cdo infon out.nc` | awk '{split($0,a," "); print a[21]}' )
if [ ${gridsize} == ${missing} ]; then
    echoerr "ERROR: All data is missing for ${e_yyyymmdd} in ${inFile_sst}"
    exit 1
fi
rm -f out.nc

#copy data from 1st of the month to 2nd of the month
#get last time value
last_day_sst=$( ncdump -v time ${RAW_DIR_MM}/sst.day.mean.${last_year}.v2.nc | grep -Eo "[0-9]*" | tail -1 )

#add 1 to $last_day_sst
second=$(($last_day_sst+1))

#extract data for 1st of month
cdo seldate,${e_yyyymmdd} ${RAW_DIR_MM}/sst.day.mean.${yearCur}.v2.nc sst_tmp.nc

#change time value in sst_tmp.nc
ncap2 -s time={${second}} sst_tmp.nc sst_new.nc

#append sst_new.nc to raw data
ncrcat ${RAW_DIR_MM}/sst.day.mean.${yearCur}.v2.nc sst_new.nc ${RAW_DIR_MM}/sst.day.mean.${yearCur}.v2_new.nc

#clean up tmp files
rm -f sst_tmp.nc sst_new.nc

if [[ ${monCur} == 01 ]]; then
    cdo seldate,${e_yyyymmdd} ${RAW_DIR_MM}/icec.day.mean.${yearCur}.v2.nc out.nc
else
    cdo seldate,${e_yyyymmdd} ${inFile_ice} out.nc
fi

#check to see if data for date is missing
gridsize=$( echo `cdo infon out.nc` | awk '{split($0,a," "); print a[20]}' )
missing=$( echo `cdo infon out.nc` | awk '{split($0,a," "); print a[21]}' )
if [ ${gridsize} == ${missing} ]; then
    echoerr "ERROR: All data is missing for ${e_yyyymmdd} in ${inFile_ice}"
    exit 1
fi
rm -f out.nc

#copy data from 1st of the month to 2nd of the month
#get last time value
last_day_ice=$( ncdump -v time ${RAW_DIR_MM}/icec.day.mean.${last_year}.v2.nc | grep -Eo "[0-9]*" | tail -1 )

#make sure $last_day sst and $last_day_ice are the same
if [[ ${last_day_sst} != ${last_day_ice} ]]; then
    echo "ERROR last timestamp in sst file ${last_day_sst} not equal to ice file ${last_day_ice}"
    exit 1
fi

#add 1 to $last_day_ice
second=$(($last_day_ice+1))

#extract data for 1st of month
cdo seldate,${e_yyyymmdd} ${RAW_DIR_MM}/icec.day.mean.${yearCur}.v2.nc ice_tmp.nc

#change time value in sst_ice.nc
ncap2 -s time={${second}} ice_tmp.nc ice_new.nc

#append sst_new.nc to raw data
ncrcat ${RAW_DIR_MM}/icec.day.mean.${yearCur}.v2.nc ice_new.nc ${RAW_DIR_MM}/icec.day.mean.${yearCur}.v2_new.nc

#clean up tmp files
rm -f ice_tmp.nc ice_new.nc

#concatenate ${yearCur} and ${yearPrev} files
if [[ $monCur == 01 ]]; then
    ncrcat ${RAW_DIR_MM}/sst.day.mean.${yearPrev}.v2.nc ${inFile_sst} ${RAW_DIR_MM}/sst.day.mean.${yearCur}.v2_new.nc tmp.sst.nc
    ncrcat  ${RAW_DIR_MM}/icec.day.mean.${yearPrev}.v2.nc ${inFile_ice} ${RAW_DIR_MM}/icec.day.mean.${yearCur}.v2_new.nc tmp.ice.nc
else
    ncrcat ${RAW_DIR_MM}/sst.day.mean.${yearPrev}.v2.nc ${RAW_DIR_MM}/sst.day.mean.${yearCur}.v2_new.nc tmp.sst.nc
    ncrcat  ${RAW_DIR_MM}/icec.day.mean.${yearPrev}.v2.nc ${RAW_DIR_MM}/icec.day.mean.${yearCur}.v2_new.nc tmp.ice.nc
fi

#do sea ice correction for ODA
ferret <<!
use tmp.sst.nc
use tmp.ice.nc
set memory/size=2000
!define a yearly axis
DEFINE AXIS/CALENDAR=JULIAN/T="${sDate}:12:00:00":"${eDate}:12:00:00":1/UNITS=days tday
let sst1 = IF icec[d=2] GT 0.25 THEN 1.8*(-1) ELSE sst[d=1]
let sst2 = sst1[gt=tday]
save/clobber/file=tmp1.nc sst2
exit
!

ncrename -v SST2,SST tmp1.nc
ncrename -v TDAY,TIME tmp1.nc
ncrename -d TDAY,TIME tmp1.nc

# Save file
cp tmp1.nc ${OUTFILE}

#regrid for ODA

REGRID_OUT=sst.day.${last_year}01_${last_yearmon}.1x1.nc

regrid_script=${BIN_DIR}/OISST_SI.ncl

if [[ ! -e ${regrid_script} ]]; then
    echoerr "ERROR: Unable to find ${regrid_script}"
fi

#ncl year=${yearCur} yearmon=${last_yearmon} ${regrid_script}
ncl out_f=\"${REGRID_OUT}\" ${regrid_script}

if [[ $? != 0 ]]; then
    echoerr "ERROR: Problem running ${regrid_script}"
    exit 1
fi

ncks --mk_rec_dmn time ${REGRID_OUT} -O ${REGRID_OUT}
cp ${REGRID_OUT} ${OUT_DIR}/

#some clean up
rm -f ferret.jnl tmp1.nc ${REGRID_OUT}

#restoring correction

restoring_sst=sst_oidaily_icecorr_icec30_fill_${last_year}01_${last_yearmon}.nc

REGRID_DIR=/home/nmme/oisst_spear/regrid #remove hard coding
cp ${REGRID_DIR}/* .

ferret <<!
use HadISST.sst.filled.nc
use tmp.sst.nc
use tmp.ice.nc
set memory/size=2000
DEFINE AXIS/CALENDAR=JULIAN/T="${sDate}:12:00:00":"${eDate}:12:00:00":1/UNITS=days tday
let sst1 = IF icec[d=3] GT 0.30 THEN 1.8*(-1) ELSE sst[d=2]
let sst2 = sst1[i=@FNR,j=@FNR,gt=tday]
save/clobber/file=tmp1.nc sst2
exit
!

ncrename -v SST2,SST tmp1.nc
ncrename -v TDAY,TIME tmp1.nc
ncrename -v LON1,LON tmp1.nc
ncrename -v LAT1,LAT tmp1.nc

ncrename -d TDAY,TIME tmp1.nc
ncrename -d LON1,LON tmp1.nc
ncrename -d LAT1,LAT tmp1.nc

mv tmp1.nc ${restoring_sst}

#regrid to tripolar for restoring

fregrid --input_mosaic lat_lon_mosaic.nc \
        --output_mosaic ocean_mosaic.nc \
        --input_dir ./ --input_file ${restoring_sst} --scalar_field SST \
        --output_file out.nc \
        --remap_file remap_file.nc

ncrename -v LAT,YH -d LAT,YH -v LON,XH -d LON,XH -v TIME,time -d TIME,time -v SST,temp out.nc

mv -f out.nc ${OUT_DIR}/${restoring_sst}

touch ${OKFILE}

# Copy files to remote site
if [[ ! -z ${XFER_TARGET} ]]; then
    for f in ${OUTFILE} ${OKFILE} ${OUT_DIR}/${REGRID_OUT} ${OUT_DIR}/${restoring_sst}
    do
        $XFER_COMMAND ${f} ${XFER_TARGET}
    done
fi
