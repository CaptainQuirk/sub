#!/bin/bash

# shellcheck disable=SC1091
#source "$_SSHUSH_C/share/functions"

# @description Extracts the OPTIONS section from the file header of a given
# sshush subcommand in the libexec folder.
#
# @example
#     options:get_raw 'git'
# @arg $1 A valid subcommand name
#
# @stdout a multiline options string
#
# @internal
# @exitcode 0 if successful
# @exitcode 1 If the subcommand does not exist
# @exitcode 2 If no OPTIONS section exists in the file
#
options:_get-raw() {
    local SUBCOMMAND=$1
    local SUBCOMMAND_FILE


    SUBCOMMAND_FILE_PATH="$_SSHUSH_LIBEXEC_PATH/sshush-$SUBCOMMAND"
    if [ ! -f "$SUBCOMMAND_FILE_PATH" ]; then
        message:log "options" "There is no $SUBCOMMAND_FILE_PATH file"
        return 1
    fi
    if ! grep -E '^#\s+OPTIONS' "$SUBCOMMAND_FILE_PATH"; then
        echo ""
        return 0
    fi
    SUBCOMMAND_FILE="$(cat "$SUBCOMMAND_FILE_PATH")"
    message:log "options" "Subcommand file : $SUBCOMMAND_FILE_PATH"

    local OPTIONS
    OPTIONS=$(echo -e "$SUBCOMMAND_FILE" | sed -n '/OPTIONS:$/,/^#$/p' | sed '1d;$d' | tr -d \#)

    echo -e "$OPTIONS"
    return 0
}

options:_get-global() {
    # shellcheck disable=2002
    cat "$_SSHUSH_ROOT/share/options/global_options.txt" | sed -n '/OPTIONS:$/,/^#$/p' | sed '1d;$d' | tr -d \#
}

# @description Builds a getopt command line to be evaluated to validate the
# options passed by the user
#
# @example
#     options:_build-get-opt-command-line 'git' <options-str>
#
# @arg $1 The subcommand name (without the leading `sshush-`)
# @arg $2 A list of options, like the one found in the top section of a
# subcommand
#
# @stdout A string of the form `getopt <opt-spec> -n 'sshush-git'`
#
# @internal
# @exitcode 0
options:_build-getopt-command-line() {
    local SUBCOMMAND=$1
    local OPTIONS=$2

    GET_OPT_SPEC="$(echo -e "$OPTIONS" | tr -d '\#' | sed 's/^[ ]*//' | awk -f "$_SSHUSH_ROOT/share/options/options.awk")"

    OPT_CMD="getopt $GET_OPT_SPEC -n 'sshush-$SUBCOMMAND'"
    message:log "options" "OPT_CMD: ${OPT_CMD}"

    echo -e "$OPT_CMD"
}

# @description Parses the arguments to validate options with getopt and fills
# an associative array passed by reference with the input value
#
# @example
#     options:parse 'git' <arrayref> 'Creating repository' --repository https://github.com/CaptainQuirk/.vim --enable-submodules --destination' .vimtest
#
# @arg $1 The subcommand name
# @arg $2 A Bash associative array
# @arg $3 An array of arguments
#
# @exitcode 0 If options are valid
# @exitcode 1 If options could not be retrieved
# @exitcode 2 If options are not valid
options:parse() {
    local SUBCOMMAND=$1
    declare -n optionsref="$2"
    local ARR=( "${@:3}" )

    local OPTIONS
    if ! OPTIONS="$(options:_get-raw "$SUBCOMMAND")"; then
        message:log "options" "Raw options could not be retrieved for subcommand $SUBCOMMAND"
        return 1
    fi
    message:log "options" "Options for $SUBCOMMAND subcommand : $OPTIONS"

    local GLOBAL_OPTIONS
    GLOBAL_OPTIONS="\n$(options:_get-global)"
    OPTIONS+="\n$GLOBAL_OPTIONS"

    local PARSE_COMMAND
    PARSE_COMMAND="$(options:_build-getopt-command-line "$SUBCOMMAND" "$OPTIONS")"
    PARSE_COMMAND+=" -- \\\ ${ARR[*]}"
    message:log "options" "Final parse command ${PARSE_COMMAND}"

    local PARSE_RESULT
    local PARSE_OUTCOME
    PARSE_RESULT=$(eval "$PARSE_COMMAND" 2>&1)
    PARSE_OUTCOME=$?
    message:log "options" "parse result: $PARSE_RESULT"
    message:log "options" "parse outcome: $PARSE_OUTCOME"

    if [ "$PARSE_OUTCOME" -ne 0 ]; then
        message:log "options" "bou"
        local ERROR
        ERROR="$(echo -e "$PARSE_RESULT" | grep "sshush-${SUBCOMMAND}" | cut -d: -f 2- | sed 's/^ //')"
        message:error "options" "Options could not be parsed.\n The following error occured: ${ERROR}."

        exit 1
    fi

    local cmd_opt
    local opt_name
    local opt_type
    local default_value

    # Create an associative array to hold the global options and their types
    # from the GLOBAL_OPTIONS variable
    declare -A global_opts
    while IFS= read -r line; do
        cmd_opt=$(echo "$line" | cut -d' ' -f6)
        if [ -z "$cmd_opt" ]; then
            continue
        fi
        opt_type=$(echo "$line" | cut -d' ' -f7)
        opt_name="$(echo "${cmd_opt#--}" | cut -d' ' -f1)"
        global_opts[$opt_name]=$opt_type
    done <<< "$GLOBAL_OPTIONS"

    # Create an associative array to hold options and their types from the
    # OPTIONS variable
    # The latter containing GLOBAL_OPTIONS, we only deal with non global ones
    declare -A options_and_types
    while IFS= read -r line; do
        cmd_opt=$(echo "$line" | cut -d' ' -f6)
        if [ -z "$cmd_opt" ]; then
            continue
        fi
        opt_type=$(echo "$line" | cut -d' ' -f7)
        opt_name="$(echo "${cmd_opt#--}" | cut -d' ' -f1)"

        # We can set a default value to boolean options but we only do this
        # if the option is not global
        default_value="$(echo -e "$line" | grep -E -o 'default:.+' | cut -d: -f2)"
        if [ -n "$default_value" ]; then
            [ -n "${global_opts[$opt_name]}" ]
            local OUTCOME=$?
            if [ "$OUTCOME" -ne 0 ]; then
                optionsref[$opt_name]=$default_value
            fi
        fi
        options_and_types[$opt_name]=$opt_type
    done <<< "$OPTIONS"

    local VAR_NAME
    local key
    for ITEM in "${ARR[@]}"
    do
        # If the argument starts with a `--`, it is a flag
        if [[ "$ITEM" =~ ^-- ]]; then

            # If the key is not null, it will be set for the next loop where we
            # may examine a value for this flag if it is not of boolean type
            key="$(echo "${ITEM#--}" | cut -d' ' -f1)"
            if [ -z "$key" ]; then
                continue
            fi

            # Here we handle the case of a boolean argument
            # whose presence indicates a truthy value
            if [ "${options_and_types[$key]}" == "boolean" ]; then

                # If this argument belongs to the global options array
                # we export it with true as a value right away
                if [ -n "${global_opts[$key]}" ]; then
                    VAR_NAME="$(options:_from-flag-to-variable "$key")"
                    eval "export SSHUSH_${VAR_NAME}=true"

                # Otherwise we add it with a truthy value in the optionsref
                # array
                else
                    optionsref[$key]=true
                fi
                continue
            fi
        # the argument is not a flag, it's a value
        else
            # If no key exists, it may be a positionnal command argument. We're
            # not handling that
            if [ -z "$key" ]; then
                continue
            fi

            local ITEM_VALUE
            # {code} typed argument need to be `base64` decoded. They are encoded
            # in the first place to deal with fragging quotes substitution
            if [ "${options_and_types[$key]}" == "{code}" ]; then
                ITEM_VALUE="$(echo "$ITEM" | base64 -d)"
            else
                # shellcheck disable=SC2034
                ITEM_VALUE=$ITEM
            fi

            # Remove any leading space as well as any leading or trailing
            # double quotes
            ITEM_VALUE="${ITEM_VALUE#\ }"
            ITEM_VALUE="${ITEM_VALUE#\"}"
            ITEM_VALUE="${ITEM_VALUE%\"}"

            # If this is a global option, we export it right away
            if [ -n "${global_opts[$key]}" ]; then
                VAR_NAME="$(options:_from-flag-to-variable "$key")"
                eval "export SSHUSH_$VAR_NAME=$ITEM_VALUE"
            # Otherwise, it's added to the optionsref associative array
            else
                # shellcheck disable=SC2034
                optionsref[$key]=$ITEM_VALUE
            fi
            key=
        fi
    done

    if ! options:_validate-global-options; then
        return 1
    fi

    options:_check-conditions

    return 0
}

options:_validate-global-options() {
    if [ "$SSHUSH_QUIET" = "true" ] && [ "$SSHUSH_VERBOSE" = "true" ]; then
        message:error "options" "--quiet or --verbose : what should it be ?"
        return 1
    fi
}

options:_check-conditions() {
    if [ -n "$SSHUSH_IF_NOT_INSTALLED" ] && shef_is_installed "$SSHUSH_IF_NOT_INSTALLED"; then
        message:debug "options" "« $SSHUSH_IF_NOT_INSTALLED » already installed. Nothing to do."
        exit 0
    fi
}

# @description Transforms a flag like string to an uppercase style string.
#
# @example
#     options:_from-flag-to-variable '--if-not-installed'
# @arg $1 Any flag
#
# @stdout An uppercase string suitable as an exported variable name
#
# @internal
# @exitcode 0 if successful
#
options:_from-flag-to-variable() {
    FLAG=$1

    FLAG=${FLAG#"--"}
    FLAG=${FLAG//-/_}
    FLAG=${FLAG^^}

    echo -e "$FLAG"
}

