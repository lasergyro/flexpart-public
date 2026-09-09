#!/bin/bash
# Cover the skewed convective boundary layer scheme (CBLFLAG=1 with -h/L > 5).
# The test checks the CBL counters and makes sure the skewed path is taken.
# 
# The CBLFLAG=1 case in run_default_options_test.sh runs on the default winds,
# 1 January 2009 over Europe, where -h/L stays between -13.4 and -4.8. This
# case runs on the ETEX winds and releases 10000 particles at midday over
# 2-14E / 44-49N -- land, mid-latitude, October -- so that a good fraction
# start under a convective boundary layer. The box is kept inland: over some
# ocean cells at this 2-degree resolution the CBL scheme returns a NaN
# timescale and the run crashes (on master too), which is a separate issue.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
MM='CBL TEST'
SUMMARY=""

# we need to read flexparts output to check the counters, so we run it through tee
# and we must not let tee hide a non zero exit status from flexpart
set -o pipefail

warning() {
    printf "%-68s[$YELLOW%10s$NC]\n" "$@" "SKIPPED"
    return 0
}

report() {
    if [ $? -eq 0 ]; then
        printf "%-68s[$GREEN%10s$NC]\n" "$@" "OK"
        return 0
    else
        printf "%-68s[$RED%10s$NC]\n" "$@" "FAILED"
        return 1
    fi
}
summary() {
    if [ $? -eq 0 ]; then
        printf "%-68s[$GREEN%10s$NC]\n" "$@" "OK"
        SUMMARY+="$1: OK\n"
        return 0
    else
        printf "%-68s[$RED%10s$NC]\n" "$@" "FAILED"
        SUMMARY+="$1: FAILED\n"
        return 1
    fi
}
# Report the current working directory and the script's location
warning "[$MM] $PWD"
cd $(dirname $0)
# Check for Flexpart executable build before
test -f ../src/FLEXPART
report "[$MM] executable: ../src/FLEXPART" || exit 1
ln -s ../src/FLEXPART .
test -d ./default_options
report "[$MM] default options: ./default_options" || exit 1
rm -rf ./current
cp -rf ./default_options ./current
# Test counters
STATUS=0
TESTSRUN=0
#
###############################################################################
# BEGIN

# The skewed scheme needs a short time step, so CTL and IFINE are raised as in
# the CBLFLAG=1 case of run_default_options_test.sh. Convection is left off.
sed -i "/LCONVECTION=/c\ LCONVECTION=      0," ./current/COMMAND
sed -i "/LTURBULENCE=/c\ LTURBULENCE=      1," ./current/COMMAND
sed -i "/CBLFLAG=/c\ CBLFLAG=          1," ./current/COMMAND
sed -i "/CTL=/c\ CTL=                10.0000," ./current/COMMAND
sed -i "/IFINE=/c\ IFINE=                 10," ./current/COMMAND
sed -i "/IBDATE=/c\ IBDATE=         19941023," ./current/COMMAND
sed -i "/IBTIME=/c\ IBTIME=           120000," ./current/COMMAND
sed -i "/IEDATE=/c\ IEDATE=         19941023," ./current/COMMAND
sed -i "/IETIME=/c\ IETIME=           180000," ./current/COMMAND

# RELEASE file: midday, 2-14E / 44-49N (see the note at the top of this file).
sed -i "/IDATE1  =/c\ IDATE1  =       19941023," ./current/RELEASES
sed -i "/ITIME1  =/c\ ITIME1  =         120000," ./current/RELEASES
sed -i "/IDATE2  =/c\ IDATE2  =       19941023," ./current/RELEASES
sed -i "/ITIME2  =/c\ ITIME2  =         120000," ./current/RELEASES
sed -i "/LON1    =/c\ LON1    =          2.000," ./current/RELEASES
sed -i "/LON2    =/c\ LON2    =         14.000," ./current/RELEASES
sed -i "/LAT1    =/c\ LAT1    =         44.000," ./current/RELEASES
sed -i "/LAT2    =/c\ LAT2    =         49.000," ./current/RELEASES
sed -i "/Z1      =/c\ Z1      =          8.000," ./current/RELEASES
sed -i "/Z2      =/c\ Z2      =        100.000," ./current/RELEASES
sed -i "/PARTS   =/c\ PARTS   =          10000," ./current/RELEASES

# CBL specific files
cp pathnames pathnames_cbl
sed -i "/output/c\./output_cbl/" ./pathnames_cbl
sed -i "s/default_winds/default_etex/g" ./pathnames_cbl
mkdir -p ./output_cbl/
./FLEXPART pathnames_cbl | tee cbl_test.txt
summary "[$MM] TEST METER $TESTSRUN (CBLFLAG=1)"
STATUS=$((STATUS + $?))
TESTSRUN=$((TESTSRUN + 1))

# Was any of the drift scheme executed?
grep "CBL gate" cbl_test.txt
awk '/CBL gate drift/   {ok=($7>0)} END{exit ok?0:1}' cbl_test.txt
summary "[$MM] TEST METER $TESTSRUN (skewed drift step entered)"
STATUS=$((STATUS + $?))
TESTSRUN=$((TESTSRUN + 1))

awk '/CBL gate release/ {ok=($7>0)} END{exit ok?0:1}' cbl_test.txt
summary "[$MM] TEST METER $TESTSRUN (init_cbl_vel entered at release)"
STATUS=$((STATUS + $?))
TESTSRUN=$((TESTSRUN + 1))

# cleanup
rm -rf current output_cbl
rm -f FLEXPART FLEXPART_ETA pathnames_cbl cbl_test.txt

#FINAL
echo -e "\n[$MM] SUMMARY:\n$SUMMARY"
echo "[$MM] Tests failed: $STATUS / $TESTSRUN"

exit $STATUS
