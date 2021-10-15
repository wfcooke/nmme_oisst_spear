;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This script regrids NCEP/NCAR Reanalysis Data from a 
; FIXED GRID (2.5 degrees by 2.5 degrees, 73 by 144) 
; to the FOAM R15 GAUSSIAN GRID (40 by 48) and outputs it to
; a netCDF file that can be read with GrADS 
;
; surface data example
;
; questions? Email Sara Rauscher at saraamy@hotmail.com
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OPEN DATA FILES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; open file to write interpolated variable(s) to

inFile="tmp1.nc"

out = addfile(out_f, "c")

; This file contains a long-term mean of monthly air temperature on a fixed grid

data = addfile("/local2/home/NMME/oisst_spear/work/"+inFile, "r")
orig = dble2flt(data->SST)
;orig = lonPivot(orig,61)
;orig&lon = orig&lon - 360
;lev = data->level
lat = orig&LAT
lon = orig&LON
time = orig&TIME
;model_lat = model->yh
;model_lon = model->xh

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; START the REGRIDDING PROCESS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

y = ispan(-90,89,1)+0.5
y@units = "degrees_north"
y@long_name = "Latitude"
y@standard_name = "latitude"
y@axis = "Y"
x = ispan(0,359,1)+0.5
x@units = "degrees_east"
x@long_name = "Longitude"
x@standard_name = "longitude"
x@axis = "X"

sst = linint2_Wrap(lon,lat,orig,True,x,y,0)
sst!0 ="time"
sst!1 ="lat"
sst!2 ="lon"
sst&time = time
sst&lat = y
sst&lon = x

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Write out data to file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

out->sst = sst 

end
