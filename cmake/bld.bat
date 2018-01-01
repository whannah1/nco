:: cmake build all NCO dependencies obtained with 'git clone'
:: Pedro Vicente

@echo off
@call "%VS140COMNTOOLS%VsDevCmd.bat" amd64

:: replace the character string '\' with '/' needed for cmake
set root_exe=%cd%
set root=%root_exe:\=/%
echo root is %root%

pushd zlib
if exist build\zlib.sln (
 echo skipping zlib build
 popd
 goto build_hdf5
) else (
  echo building zlib
  mkdir build
  pushd build
  cmake .. -G "Visual Studio 14 2015" ^
           -DCMAKE_BUILD_TYPE=Debug ^
           -DBUILD_SHARED_LIBS=OFF
  msbuild zlib.sln /target:build /property:configuration=debug
  cp %root%\zlib\build\zconf.h %root%\zlib
  popd
  popd
)

:build_hdf5
pushd hdf5
if exist build\bin\Debug\h5dump.exe (
 echo skipping hdf5 build
 popd
 goto build_curl
) else (
  echo building hdf5
  mkdir build
  pushd build
  cmake .. -G "Visual Studio 14 2015" ^
           -DCMAKE_BUILD_TYPE=Debug ^
           -DBUILD_SHARED_LIBS=OFF ^
           -DBUILD_STATIC_EXECS=ON ^
           -DBUILD_TESTING=OFF ^
           -DHDF5_BUILD_EXAMPLES=OFF ^
           -DHDF5_BUILD_CPP_LIB=OFF ^
           -DHDF5_ENABLE_Z_LIB_SUPPORT=ON ^
           -DH5_ZLIB_HEADER=%root%/zlib/zlib.h ^
           -DZLIB_STATIC_LIBRARY:FILEPATH=%root%/zlib/build/Debug/zlibstaticd.lib ^
           -DZLIB_INCLUDE_DIRS:PATH=%root%/zlib
  msbuild HDF5.sln /target:build /property:configuration=debug
  popd
  popd
)

:build_curl
pushd curl
if exist build\curl.sln (
 echo skipping curl build
 popd
 goto build_netcdf
) else (
  echo building curl
  mkdir build
  pushd build
  cmake .. -G "Visual Studio 14 2015" ^
           -DCMAKE_BUILD_TYPE=Debug ^
           -DBUILD_SHARED_LIBS=OFF ^
           -DBUILD_TESTING=OFF ^
           -DHTTP_ONLY=ON ^
           -DENABLE_DEBUG=ON ^
           -DENABLE_CURLDEBUG=ON ^
           -DCURL_STATICLIB=ON
  msbuild curl.sln /target:build /property:configuration=debug
  popd
  popd
)


:build_netcdf
pushd netcdf-c
if exist build\ncdump\ncdump.exe (
 echo skipping netcdf build
 popd
 goto test_netcdf
) else (
  echo building netcdf
  mkdir build
  pushd build
  cmake .. -G "Visual Studio 14 2015" ^
           -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON ^
           -DENABLE_TESTS=OFF ^
           -DCMAKE_BUILD_TYPE=Debug ^
           -DBUILD_SHARED_LIBS=OFF ^
           -DHDF5_HL_LIBRARY=%root%/hdf5/build/bin/Debug/libhdf5_hl_D.lib ^
           -DHDF5_C_LIBRARY=%root%/hdf5/build/bin/Debug/libhdf5_D.lib ^
           -DHDF5_INCLUDE_DIR=%root%/hdf5/src ^
           -DZLIB_LIBRARY:FILE=%root%/zlib/build/Debug/zlibstaticd.lib ^
           -DZLIB_INCLUDE_DIR:PATH=%root%/zlib ^
           -DHAVE_HDF5_H=%root%/hdf5/build ^
           -DHDF5_HL_INCLUDE_DIR=%root%/hdf5/hl/src ^
           -DCURL_LIBRARY=%root%/curl/build/lib/Debug/libcurl-d.lib ^
           -DCURL_INCLUDE_DIR=%root%/curl/include
  msbuild netcdf.sln /target:build /property:configuration=debug
  popd
  popd
)

:test_netcdf
if exist %root%\netcdf-c\build\ncdump\ncdump.exe (
 echo testing netcdf build
 %root%\netcdf-c\build\ncdump\ncdump.exe http://www.esrl.noaa.gov/psd/thredds/dodsC/Datasets/cmap/enh/precip.mon.mean.nc
 goto build_nco
)


:build_nco
if exist Debug\ncks.exe (
 echo skipping nco build
 goto test_nco
) else (
  rm -rf CMakeCache.txt CMakeFiles
  cmake .. -G "Visual Studio 14 2015" ^
  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON ^
  -DNCO_MSVC_USE_MT=no ^
  -DNETCDF_INCLUDE:PATH=%root%/netcdf-c/include ^
  -DNETCDF_LIBRARY:FILE=%root%/netcdf-c/build/liblib/Debug/netcdf.lib ^
  -DHDF5_LIBRARY:FILE=%root%/hdf5/build/bin/Debug/libhdf5_D.lib ^
  -DHDF5_HL_LIBRARY:FILE=%root%/hdf5/build/bin/Debug/libhdf5_hl_D.lib ^
  -DZLIB_LIBRARY:FILE=%root%/zlib/build/Debug/zlibstaticd.lib ^
  -DCURL_LIBRARY:FILE=%root%/curl/build/lib/Debug/libcurl-d.lib
  msbuild nco.sln /target:build /property:configuration=debug
)

:test_nco
%root_exe%\netcdf-c\build\ncgen\ncgen.exe -k netCDF-4 -b -o %root_exe%\..\data\in_grp.nc %root_exe%\..\data\in_grp.cdl
pushd Debug
@echo on
ncks.exe --jsn_fmt 2 -C -g g10 -v two_dmn_rec_var %root_exe%\..\data\in_grp.nc
ncks.exe -v lat http://www.esrl.noaa.gov/psd/thredds/dodsC/Datasets/cmap/enh/precip.mon.mean.nc
@echo off
popd
echo done