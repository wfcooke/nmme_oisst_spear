#!/bin/sh

. /usr/local/Modules/default/init/sh
module load anaconda
export PATH="/nbhome/Colleen.McHugh/miniconda/bin:$PATH"


source activate geo_scipy
which python


python /home/nmme/oisst_spear/bin/get_oisst_data.py

conda deactivate
