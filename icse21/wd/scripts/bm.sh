#!/bin/bash
set -Eeuo pipefail
WORK_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
# cleanup() {
#     trap - SIGINT SIGTERM ERR EXIT
#     # script cleanup here
# }
# trap cleanup SIGINT SIGTERM ERR EXIT

ARG_J=0
ARG_REP=11
ARG_REP_PARA=0
N_CPUS=0
DRY_RUN=0
PROGS=()
ANALYZERS=()
ANALYZED_PROGS=()

msg() {
    echo >&2 -e "$@"
}

die() {
    for i; do
        msg "${RED}$i${NOFORMAT}"
    done
    exit 1
}

finish() {
    msg
    msg "${GREEN}$@${NOFORMAT}"
    if [[ $DRY_RUN == 1 ]]; then
        msg "${GREEN}** Finish DRY RUN  **${NOFORMAT}"
    fi
    exit 0
}

print_cmd() {
    local cmd=("$@")
    echo >&2 -ne "${RED}+ "
    printf '%q ' "${cmd[@]}"
    msg "${NOFORMAT}"
}

run_always() {
    print_cmd "$@"
    "$@"
}

run() {
    print_cmd "$@"
    if [[ $DRY_RUN == 0 ]]; then
        "$@"
    fi
}

clean_all_res() {
    run rm -rf res/*
}

clean_res() {
    local NAME=$1
    run rm -rf res/$NAME log/$NAME 2/$NAME.cachedb
    run mkdir -p res/$NAME log/${NAME}/full
}

###################

run_bm_impl() {
    local OPTS="$1"
    local NAME=$2
    local FULL=$3
    clean_res $NAME

    run ./gt -J2 -crwx $OPTS -F 2/$NAME --rep "$ARG_REP" -O "res/$NAME/a_{i}.txt" -j "$ARG_J" --rep-para "$ARG_REP_PARA" -L "log/$NAME"
    if [[ $FULL == full ]]; then
        run ./gt -J2 -crwx $OPTS -F 2/$NAME -O "res/$NAME/full.txt" --full -j "$ARG_J" -L "log/$NAME/full"
    fi
}

has_full() {
    case "$1" in
    id | uname | cat | mv | ln | date | join | sort | grin | ngircd) return 0 ;;
    *) return 1 ;;
    esac
}

run_single_bm() {
    local NAME=$1
    if has_full $NAME; then
        local FULL=full
    else
        local FULL=no_full
    fi
    case "$NAME" in
    id | uname | cat | mv | ln | date | join | sort | ls | grin | pylint | unison | bibtex2html | cloc | ack)
        run_bm_impl "-G" $NAME $FULL
        ;;
    vsftpd | ngircd)
        run_bm_impl "-Y" $NAME $FULL
        ;;
    *) die "Unknown program $NAME." ;;
    esac
}

add_predefined_progs() {
    case "$1" in
    fast) PROGS+=(id uname cat mv ln date join vsftpd) ;;
    mid) PROGS+=(sort ls grin unison ngircd) ;;
    slow) PROGS+=(pylint bibtex2html cloc ack) ;;
    all)
        add_predefined_progs fast
        add_predefined_progs mid
        add_predefined_progs slow
        ;;
    *) die "Unknown type $1." ;;
    esac
}

do_bm_progs() {
    for NAME in "$@"; do
        msg
        run_single_bm $NAME
    done
}

run_analyze_mcc() {
    local NAME=$1
    if ! has_full $NAME; then
        msg "${GREEN}+ (mcc) Skip $NAME because full data is not available. ${NOFORMAT}"
        return 0
    fi
    local PREFIX=res/Analyze/mcc
    run mkdir -p $PREFIX
    run ./gt -A0 -T3 -GF 2/$NAME -I res/$NAME/full.txt,res/$NAME/a_{i}.txt --rep $ARG_REP --rep-para $ARG_REP_PARA -P $PREFIX/$NAME.csv \
        --params-fields _repeat_id,_thread_id,delta_locs,avg_mcc,cnt_exact,cnt_interactions,cnt_wrong,avg_f,n_configs,wrong_locs
}

STAT_FIELDS=_repeat_id,n_configs,n_locs,t_search,t_total,cnt_singular,cnt_and,cnt_or,cnt_mixed,cnt_pure,cnt_mix_ok,cnt_mix_fail,cnt_total,hash,iter,n_cache_hit,n_locs_total,n_locs_uniq,max_len,median_len,repeat_id,t_runner,t_runner_total,_thread_id

run_analyze_stat() {
    local NAME=$1
    local PREFIX=res/Analyze/stat
    run mkdir -p $PREFIX
    run ./gt -A0 -T2 -GF 2/$NAME -I res/$NAME/a_{i}.txt --rep $ARG_REP --rep-para $ARG_REP_PARA -P $PREFIX/$NAME.csv --params-fields $STAT_FIELDS
}

run_analyze_stat_full() {
    local NAME=$1
    local PREFIX=res/Analyze/stat_full
    if ! has_full $NAME; then
        msg "${GREEN}+ (stat_full) Skip $NAME because full data is not available. ${NOFORMAT}"
        return 0
    fi
    run mkdir -p $PREFIX
    run ./gt -A0 -T2 -GF 2/$NAME -I res/$NAME/full.txt -P $PREFIX/$NAME.csv --params-fields $STAT_FIELDS
}

run_analyze_cmin() {
    local NAME=$1
    local PREFIX=res/Analyze/cmin
    if has_full $NAME; then
        local INP=res/$NAME/full.txt
    else
        local INP=res/$NAME/a_0.txt
    fi
    run mkdir -p $PREFIX
    run ./gt -A0 -T4 -F 2/$NAME -I $INP --rep 20 --rep-para $ARG_REP_PARA -P $PREFIX/$NAME.csv
}

run_analyze_stat_len() {
    local NAME=$1
    local PREFIX=res/Analyze/stat_len
    if has_full $NAME; then
        local INP=res/$NAME/full.txt
    else
        local INP=res/$NAME/a_0.txt
    fi
    run mkdir -p $PREFIX
    run ./gt -A0 -T5 -GF 2/$NAME -I $INP -P $PREFIX/$NAME.csv
}

run_single_analyze() {
    local ana_type=$1
    shift
    case $ana_type in
    2 | stat)
        run_analyze_stat "$@"
        ;;
    2.1 | statf | stat_full)
        run_analyze_stat_full "$@"
        ;;
    2.2 | cmin)
        run_analyze_cmin "$@"
        ;;
    statl | stat_len)
        run_analyze_stat_len "$@"
        ;;
    3 | mcc)
        run_analyze_mcc "$@"
        ;;
    *) die "Unknown analyze type: $ana_type" ;;
    esac
}

do_analyze() {
    for NAME in "$@"; do
        msg
        if [[ -d res/$NAME ]]; then
            ANALYZED_PROGS+=($NAME)
            for TYPE in "${ANALYZERS[@]}"; do
                run_single_analyze $TYPE $NAME
            done
        else
            msg "Result not found for $NAME at res/$NAME"
        fi
    done
}

###################

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
    cat <<EOF
NAME
        bm.sh - Run GenTree benchmarks

SYNOPSIS
        $(basename "${BASH_SOURCE[0]}") [options] [PROGRAMS ...]

OPTIONS
	-h, --help
		Prints this and exits
	-c, --clean
		Clean all previous benchmark results
	-j, --jobs
		Number of parallel program runners
	-p, --rep-para
		Number of parallel benchmark (using shared program runners)
	-d, --dry
		Dry run
	--fast
		Add fast programs    (less than 5 mins)
	--mid
		Add mid programs     (around 1 hours)
	--slow
		Add slow programs    (upto 8 hours)
	--all
		Add all programs
    -b, --bm, --benchmark
        Run benchmark 11 times
    --benchmark-times n
        Run benchmark n times
    --analyze-[type], -A[type], -a [type]
        Run analyze [type]: summary, mcc, cmin
EOF

    exit 0
}

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
    else
        NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
    fi
}

parse_params() {
    # default values of variables set from params
    flag=0
    param=''

    while :; do
        case "${1-}" in
        --) break ;;
        -h | --help) usage ;;
        -c | --clean) ARG_DO_CLEAN=1 ;;
        -v | --verbose) set -x ;;
        --no-color) NO_COLOR=1 ;;
        -j | --jobs)
            ARG_J=$2
            shift
            ;;
        -p | --rep-para)
            ARG_REP_PARA=$2
            shift
            ;;
        -d | --dry) DRY_RUN=1 ;;
        --fast | --mid | --slow | --all) add_predefined_progs ${1/--/} ;;
        -b | --bm | --benchmark) ARG_DO_BM=1 ;;
        --benchmark-times)
            ARG_DO_BM=1
            ARG_REP=$2
            shift
            ;;
        -a)
            ANALYZERS+=("$2")
            shift
            ;;
        --analyze-*) ANALYZERS+=("${1/--analyze-/}") ;;
        -A*) ANALYZERS+=("${1/-A/}") ;;
        -?*) die "Unknown option: $1" ;;
        ?*) PROGS+=("$1") ;;
        *) break ;;
        esac
        shift
    done

    return 0
}

dedup_progs() {
    declare -A set_progs
    local NEW_PROGS=()
    for i in "${PROGS[@]}"; do
        if [[ -z ${set_progs[$i]:-} ]]; then
            NEW_PROGS+=("$i")
        fi
        set_progs["$i"]=1
    done
    unset set_progs
    PROGS=("${NEW_PROGS[@]}")
}

main_fn() {
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
    parse_params "$@"
    dedup_progs
    setup_colors

    if [[ $DRY_RUN == 1 ]]; then
        msg "${GREEN}** Start DRY RUN **${NOFORMAT}\n"
    fi
    run_always cd "$WORK_DIR"

    if [[ -v ARG_DO_CLEAN ]]; then
        clean_all_res
        finish "Cleaned all results"
    fi

    if [[ $N_CPUS == 0 ]]; then
        local logicalCpuCount=$(lscpu -p | egrep -v '^#' | wc -l)
        local physicalCpuCount=$(lscpu -p | egrep -v '^#' | sort -u -t, -k 2,4 | wc -l)
        N_CPUS=$physicalCpuCount
    fi
    msg "${GREEN}+ N_CPUS = $N_CPUS ${NOFORMAT}"
    if [[ $ARG_J == 0 ]]; then
        ARG_J=$N_CPUS
    fi
    msg "${GREEN}+ ARG_J = $ARG_J ${NOFORMAT}    # parallel program runners"
    if [[ $ARG_REP_PARA == 0 ]]; then
        ((ARG_REP_PARA = ($N_CPUS + 3) / 4))
    fi
    msg "${GREEN}+ ARG_REP_PARA = $ARG_REP_PARA ${NOFORMAT}    # parallel benchmarks"

    msg "${GREEN}+ PROGS = ( ${PROGS[@]} )${NOFORMAT}"
    msg "${GREEN}+ ANALYZERS = ( ${ANALYZERS[@]} )${NOFORMAT}"

    if [[ -v ARG_DO_BM ]]; then
        do_bm_progs "${PROGS[@]}"
        finish "+ Done benchmarks: ${PROGS[@]}"
    fi

    if [[ ${#ANALYZERS[@]} -ne 0 ]]; then
        do_analyze "${PROGS[@]}"
        finish "+ Done analyze\n  ANALYZED_PROGS = ( ${ANALYZED_PROGS[@]} )\n  ANALYZERS = ( ${ANALYZERS[@]} )"
    fi
}

(main_fn "$@")
