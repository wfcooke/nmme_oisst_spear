Recreate lat_lon_grid.txt with 

cp lat_lon_grid1.nc lat_lon_grid.nc
ncks -A lat_lon_grid2.nc lat_lon_grid.nc

Note
lat_lon_grid1.nc and lat_lon_grid2.nc were created via 

ncks -v x,y,area lat_lon_grid.nc lat_lon_grid1.nc
ncks -v dx,dy,tile,angle_dx,arcx  lat_lon_grid.nc lat_lon_grid2.nc
to try to get around the 100Mb limit of Github.

