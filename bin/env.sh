# Base directory where everything will be placed
BASE_DIR=/local2/home/NMME/oisst_spear

# Where all work is to be done
# TODO: This could be a tmp locaton.
WORK_DIR=${BASE_DIR}/work

# Location of raw data files
#
# Should we archive the RAW data files?
# Or can they simply be downloaded each time?
# Currently we save the raw files between each run
RAW_DIR=${BASE_DIR}/raw

# Location of output NetCDF files
# This is the GFDL archive location
OUT_DIR=${BASE_DIR}/NetCDF

# Uncommenting the following variable will allow the script
# to process every year/month of raw data files it encounters
# PROCESS=all

# Remote transfer variables
# If XFER_TARGET is not set, no transfer will be done
# The command to perform the transfer should look similar to an
# scp command:
# scp [<options>] <source> [<host>:]<target>
# 
# The command run will be:
# ${XFER_COMMAND} ${file} ${XFER_TARGET}
#
# Thus XFER_TARGET should have the [<host>:] included
#XFER_COMMAND='gcp --sync -cd --checksum'
XFER_COMMAND='gcp --sync -cd '
XFER_TARGET=gfdl:/archive/$USER/NMME/INPUTS/oisst_spear/


# Can run other sh commands
# For example, if need to load certain environment modules for compiled programs to run

# The following loads the requried modules to run on the GFDL workstations
. /usr/local/Modules/default/init/sh
module load python/3.10-pyferret
module load ncl/6.6.2
module load cdo
module load nco/5.1.5
module load fre-nctools/2023.01.02
module load gcp
