#!/bin/sh -xe

echoerr() {
    echo "$@" 1>&2
}

# Verify the time passed in fits the YYYYMM format.
#
# verifyTime "YYYYMM"
verifyTime () {
    local timeString=$@

    len=$( expr length "${timeString}" )
    if [[ $len -ne 6 ]]; then
        echoerr "FATAL: Time string is not in the correct format.  Expected 'YYYYMM'."
        echoerr "FATAL: Got '$timeString'."
        exit 65
    fi

    local yr=$( expr substr "${timeString}" 1 4 )
    local mo=$( expr substr "${timeString}" 5 2 )
    if [[ $yr -le 0 ]]; then
        echoerr "FATAL: Not a valid year.  Year must be greater than 0.  Got '$yr'."
        exit 65
    fi
    # The "10#" is needed to keep sh from using ocal numbers
    if [[ "10#$mo" -lt 1 || "10#$mo" -gt 12 ]]; then
        echoerr "FATAL: Not a valid month.  Month must be in the range [1,12].  Got '%mo'."
        exit 65
    fi
}

usage() {
    echo "Usage: do_oisst_qc.sh [OPTIONS]"
}

help () {
    usage
    echo ""
    echo "Options:"
    echo "     -h"
    echo "          Display usage information."
    echo ""
    echo "     -o <out_file>"
    echo "          Write the output to file <out_file> instead of default file"
    echo "          location."
    echo ""
    echo "     -t <YYYYMM>"
    echo "          Create OISST file for month MM and year YYYY"
    echo "          Default: Current year/month"
    echo ""
    echo "     -i <file>"
    echo "          Use the files in <file> to generate a specific file.  Must use"
    echo "          the -o and -t options, otherwise the script may think the file"
    echo "          has already been generated."
    echo ""
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

# Read in command line options
while getopts :ho:t:i: OPT; do
    case "$OPT" in
        h)
            help
            exit 0
            ;;
        o)
            OUTFILE=${OPTARG}
            ;;
        t)
            verifyTime ${OPTARG}
            yearCur=$( expr substr "${OPTARG}" 1 4 )
            monCur=$( expr substr "${OPTARG}" 5 2 )
            ;;
        i)
            inLogFile=${OPTARG}
            ;;
        \?)
            echoerr "Unknown option:" $${OPTARG}
            usage >&2
            exit 1
            ;;
    esac
done

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
elif [[ ! -e ${RAW_DIR} ]]; then
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

# Convert the start/end Dates  to d-mmm-yyyy and yymmdd
firstDate="${yearPrev}-12-31"
echo ${firstDate}
lastDate="${yearCur}-${monCur}-01"
echo ${lastDate}
sDate=$( date -d $firstDate '+%-d-%b-%Y' )
eDate=$( date -d $lastDate '+%-d-%b-%Y' )
s_yymmdd=$( date -d $firstDate '+%y%m%d' )
e_yymmdd=$( date -d $lastDate '+%y%m%d' )

# Output file
sst_spear=sst_oidaily_icecorr_icec25_${yearCur}.nc

if [[ -z $OUTFILE ]]; then
    # Set the default OUTFILE if not set by option above
    OUTFILE=${OUT_DIR}/${sst_spear}
fi

# Check if the output file exists. If it exists, exit.
OKFILE=${OUT_DIR}/${yearCur}${monCur}.OK
if [[ -e ${OKFILE} ]]; then
    echoerr "File '${OKFILE}' already exists.  Not processing."
    exit 0
fi

# Begin actual work, need to be in WORK_DIR
cd ${WORK_DIR}

    inFile_sst="${RAW_DIR}/sst.day.mean.${yearCur}.v2.nc"
    inFile_ice="${RAW_DIR}/icec.day.mean.${yearCur}.v2.nc"
if [[ ! -e ${inFile_sst} || ! -e ${inFile_ice} ]]; then
    echoerr "ERROR: Unable to find raw data file file for ${yearCur}-${m}-${d}"
    exit 1 
fi                    

#concatenate ${yearCur} and ${yearPrev} files
ncrcat ${RAW_DIR}/sst.day.mean.${yearPrev}.v2.nc ${RAW_DIR}/sst.day.mean.${yearCur}.v2.nc tmp.sst.nc
ncrcat  ${RAW_DIR}/icec.day.mean.${yearPrev}.v2.nc ${RAW_DIR}/icec.day.mean.${yearCur}.v2.nc tmp.ice.nc

#do sea ice correction for ODA
ferret <<!
use tmp.sst.nc
use tmp.ice.nc
set memory/size=1000
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

REGRID_OUT=sst.day.${yearCur}.1x1.nc

regrid_script=${BIN_DIR}/OISST_SI.ncl

if [[ ! -e ${regrid_script} ]]; then
    echoerr "ERROR: Unable to find ${regrid_script}"
fi

ncl ${regrid_script}

if [[ $? != 0 ]]; then
    echoerr "ERROR: Problem running ${regrid_script}"
    exit 1
fi

ncks --mk_rec_dmn time ${REGRID_OUT} -O ${REGRID_OUT}
cp ${REGRID_OUT} ${OUT_DIR}/

#some clean up
rm -f ferret.jnl tmp1.nc ${REGRID_OUT}

#restoring correction

restoring_sst=sst_oidaily_icecorr_icec30_fill_${yearCur}.nc

REGRID_DIR=/home/cem/git/nmme/oisst/regrid #remove hard coding
cp ${REGRID_DIR}/* .

ferret <<!
use HadISST.sst.filled.nc
use tmp.sst.nc
use tmp.ice.nc
set memory/size=1000
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
