#!/bin/sh
set -x
# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
SKIP_INSTALL="false"
SMP="true"

usage() {
    echo "Usage: $0 [-s <true|false>] [-m <true|false>]" 1>&2
    exit 1
}

while getopts "s:m:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    m) SMP="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

parse_output() {
    # Parse each type of results
    # A note on the sed line used below to strip color codes:
    # busybox's sed does not implement e.g. '\x1b', and so the literal
    # control code is used below. Do not copy/paste it, or it will lose
    # its magic.
    grep -e PASS -e SKIP -e FAIL "${RESULT_LOG}" | \
      sed 's/\[[0-9]*m//g' | \
      sed -e 's/PASS/pass/g' \
          -e 's/SKIP/skip/g' \
          -e 's/FAIL/fail/g' | \
       awk '{print $2" "$1}'  >> "${RESULT_FILE}"
    cat "${RESULT_FILE}"
}

kvm_unit_tests_run_test() {
    info_msg "running kvm unit tests ..."
    if [ "${SMP}" = "false" ]; then
        taskset -c 0 ./run_tests.sh -v | tee -a "${RESULT_LOG}"
    else
        ./run_tests.sh -v | tee -a "${RESULT_LOG}"
    fi
}

kvm_unit_tests_build_test() {
    info_msg "git clone kvm unit tests ..."
    git clone https://git.kernel.org/pub/scm/virt/kvm/kvm-unit-tests.git --depth 1
    # shellcheck disable=SC2164
    cd kvm-unit-tests
    info_msg "configure kvm unit tests ..."
    ./configure
    info_msg "make kvm unit tests ..."
    make || true
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="binutils gcc make python sed tar wget"
        ;;
      fedora|centos)
        pkgs="binutils gcc glibc-static make python sed tar wget"
        ;;
    esac
    install_deps "${pkgs}" "${SKIP_INSTALL}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"
# shellcheck disable=SC2164
cd "${OUTPUT}"

info_msg "About to run kvm unit tests ..."
info_msg "Output directory: ${OUTPUT}"


if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "kvm-unit-tests skipped"
else
  # Install packages
  install
fi

# Build kvm unit tests
kvm_unit_tests_build_test

# Run kvm unit tests
kvm_unit_tests_run_test

# Parse and print kvm unit tests results
parse_output
