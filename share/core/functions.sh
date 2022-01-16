#!/usr/bin/env bash

message:debug() {
    local SCOPE=$1
    local MESSAGE=$2

    if [ "$SSHUSH_QUIET" = true ]; then
        return
    fi

    if [ "$SSHUSH_VERY_VERBOSE" = "false" ]; then
        return
    fi

    echo -e "\033[100m[⚙ $SCOPE]\033[0m $MESSAGE"
}

message:info() {
    local SCOPE=$1
    local MESSAGE=$2

    if [ "$SSHUSH_QUIET" = true ]; then
        return
    fi

    if [ "$SSHUSH_VERY_VERBOSE" = "false" ]; then
        return
    fi

    echo -e "\033[44m[ℹ $SCOPE]\033[0m $MESSAGE"
}

message:error() {
    local SCOPE
    local MESSAGE=$2

    SCOPE="$(caller 1 | cut -d' ' -f3 | cut -d- -f2)"

    echo -e "\033[101m[ﮖ $SCOPE]\033[0m $MESSAGE"
}

message:warning() {
    local SCOPE=$1
    local MESSAGE=$2

    if [ "$SSHUSH_QUIET" = true ]; then
        return
    fi

    echo -e "\033[103m[ $SCOPE]\033[0m $MESSAGE"
}

message:success() {
    local SCOPE=$1
    local MESSAGE=$2

    if [ "$SSHUSH_QUIET" = true ]; then
        return
    fi

    echo -e "\033[32m[ $SCOPE]\033[0m $MESSAGE"
}

message:log() {
    local SCOPE=$1
    local MESSAGE=$2
    echo -e "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")][$SCOPE] $MESSAGE" >> /tmp/sshush.log
}

dump_array() {
    declare -n DUMP_ARR="$1"

    printf "%s\n" "${!DUMP_ARR[@]}" "${DUMP_ARR[@]}" | pr -2t
}

