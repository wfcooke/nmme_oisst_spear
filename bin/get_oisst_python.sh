#!/bin/sh

. /usr/local/Modules/default/init/sh
module load miniforge
export PATH="/nbhome/Colleen.McHugh/miniconda/bin:$PATH"


source activate geo_scipy
which python

BIN_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
echo $BIN_DIR

python ${BIN_DIR}/get_oisst_data.py

conda deactivate
