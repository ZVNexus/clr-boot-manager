#!/bin/bash
#
# This file is part of clr-boot-manager.
#
# Copyright © 2017 Ikey Doherty
#
# clr-boot-manager is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1
# of the License, or (at your option) any later version.
#

set -e

testRoot=`pwd`
suppressions="$testRoot/sgcheck.suppressions"
coverDir="$testRoot/outCoverage"

# build configuration/arguments
configs=()
systemdConfig="-Dwith-bootloader=systemd-boot"
shimSystemdConfig="-Dwith-bootloader=shim-systemd-boot"
withCoverage=true
fullConfigSet=false
stockConfig=false

print_help() {
    echo -e "run-test-suite.sh [flags] [targets]
Flags:
    --help|help		Show this help list
    --no-coverage	Don't run the coverage generation

Targets:
    shim-systemd-boot   run test with shim-systemd-boot backend
    stock		run test on top of a stock configuration
    systemd 	        run test with systemd backend
    all			run all the above"
}

# Just perform a single build
build_one() {
    meson build --buildtype debugoptimized -Db_coverage=true --prefix=/usr --sysconfdir=/etc \
	  --datadir=/usr/share -Dwith-systemd-system-unit-dir=/lib/systemd/system $*
    ninja -C build
}

# Do a check with the various valgrind tools
check_valgrind() {
    local valgrindArgs="valgrind --suppressions=\"$suppressions\" --error-exitcode=1"

    # Memory test
    meson test -C build --print-errorlogs --logbase=memcheck \
	  --wrap="$valgrindArgs --tool=memcheck --leak-check=full --show-reachable=no"
    meson test -C build --print-errorlogs --logbase=helgrind --wrap="$valgrindArgs --tool=helgrind"
    meson test -C build --print-errorlogs --logbase=drd --wrap="$valgrindArgs --tool=drd"
}

# Do a "normal" test suite check
check_normal() {
    meson test -C build --print-errorlogs
}

# Store the coverage report. If we have one, merge the new report. Finally,
# strip any unneeded noise from the report, to prepare it for upload
stash_coverage() {
    ninja -C build coverage-html
    local coverageFile="$coverDir/coverage.info"
    local sampleFile="./build/meson-logs/coverage.info"

    if [[ ! -d "$coverDir" ]]; then
        mkdir "$coverDir"
    fi

    # Does this guy exist?
    if [[ ! -s "$coverageFile" ]]; then
        cp -v "$sampleFile" "$coverageFile"
    else
        # Merge them!
        lcov -a "$coverageFile" -a "$sampleFile" -o "${coverageFile}.tmp"

        # Stick this guy back as the main coverage file now
        mv "${coverageFile}.tmp" "$coverageFile"
    fi

    if [[ ! -s "$coverageFile" ]]; then
	# Ensure we remove any unnecessary junk now
	lcov --remove "$coverageFile" 'tests/*' '/usr/*' --output-file "$coverageFile"
    fi
}

set_full_config() {
    fullConfigSet=true
    configs=("" $systemdConfig $shimSystemdConfig)
}

for curr in "$@"; do
    case $curr in
	"stock")
	    if [[ "$fullConfigSet" = false ]]; then
		stockConfig=true
		configs+=("")
	    fi;;
	"systemd")
	    if [[ "$fullConfigSet" = false ]]; then
		configs+=($systemdConfig)
	    fi;;
	"shim-systemd-boot")
	    if [[ "$fullConfigSet" = false ]]; then
		configs+=($shimSystemdConfig)
	    fi;;
	"all")
	    set_full_config;;
	"--no-coverage")
	    withCoverage=false;;
	"help"|"--help")
	    print_help;
	    exit 0;;
    esac
done

if [[ ${#configs[@]} -eq 0 ]] && [[ "$stockConfig" = false ]]; then
    set_full_config
fi

for buildArg in "${configs[@]}"; do
    # Let's do our stock configuration first
    echo "Performing build: $buildArg"

    # nuke the build dir
    if [[ -d "build" ]]; then
        rm -rf "build"
    fi

    build_one $buildArg --libdir=/usr/lib64
    check_normal
    check_valgrind

    if [[ "$withCoverage" = true ]]; then
	# Stash the coverage as we'll want this guy later
	stash_coverage
    fi
done
