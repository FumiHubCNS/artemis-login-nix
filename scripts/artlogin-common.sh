#!/usr/bin/env bash

# ============================================================
# ARTEMIS common login/setup functions
#
# This file is intended to be sourced from artlogin-nix.
#
# Required environment variables:
#   ART_ANALYSIS_DIR
#
# Optional:
#   ART_DATA_DIR
#   ARTLOGIN_USE_GIT_FLOW
#   ARTLOGIN_INIT_SUBMODULES
#   REPO_BRANCH
#
# Repository URL is resolved by repo_resolve_url(),
# which should be provided by scripts/repo-resolve.sh.
# ============================================================


# ------------------------------------------------------------
# Utilities
# ------------------------------------------------------------

artlogin_error()
{
    echo "artlogin: error: $*" >&2
}


artlogin_info()
{
    echo "artlogin: $*"
}


artlogin_yes_no()
{
    local prompt="$1"
    local answer

    while true; do
        printf "%s (y/n): " "$prompt"
        read -r answer

        case "$answer" in
            y|Y|yes|YES|Yes)
                return 0
                ;;
            n|N|no|NO|No)
                return 1
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}


# ------------------------------------------------------------
# Configuration validation
# ------------------------------------------------------------

artlogin_check_environment()
{
    if [ -z "${ART_ANALYSIS_DIR:-}" ]; then
        artlogin_error "ART_ANALYSIS_DIR is not set."
        return 1
    fi

    if [ ! -d "$ART_ANALYSIS_DIR" ]; then
        artlogin_info "ART_ANALYSIS_DIR does not exist."
        artlogin_info "Creating:"
        echo "  $ART_ANALYSIS_DIR"

        if ! mkdir -p "$ART_ANALYSIS_DIR"; then
            artlogin_error "failed to create ART_ANALYSIS_DIR:"
            echo "  $ART_ANALYSIS_DIR" >&2
            return 1
        fi
    fi

    if ! declare -F repo_resolve_url >/dev/null 2>&1; then
        artlogin_error "repo_resolve_url() is not defined."
        artlogin_error "Source scripts/repo-resolve.sh first."
        return 1
    fi

    return 0
}


# ------------------------------------------------------------
# Git user configuration
# ------------------------------------------------------------

artlogin_setup_git_user()
{
    local fullname
    local email
    local answer

    if git config --local user.name >/dev/null 2>&1; then
        ART_USER_FULLNAME="$(git config --local user.name)"
    else
        while true; do
            printf "input fullname: "
            read -r fullname

            printf "fullname: %s\n" "$fullname"

            if artlogin_yes_no "OK?"; then
                break
            fi
        done

        git config --local user.name "$fullname"
        ART_USER_FULLNAME="$fullname"
    fi


    if git config --local user.email >/dev/null 2>&1; then
        ART_USER_EMAIL="$(git config --local user.email)"
    else
        while true; do
            printf "input email address: "
            read -r email

            printf "email: %s\n" "$email"

            if artlogin_yes_no "OK?"; then
                break
            fi
        done

        git config --local user.email "$email"
        ART_USER_EMAIL="$email"
    fi

    export ART_USER_FULLNAME
    export ART_USER_EMAIL

    artlogin_info "Git user:"
    echo "  name : $ART_USER_FULLNAME"
    echo "  email: $ART_USER_EMAIL"
}


# ------------------------------------------------------------
# Git repository initialization
# ------------------------------------------------------------

artlogin_initialize_repository()
{
    # git-flow is optional.
    #
    # Enable in env/*.conf with:
    #
    #   ARTLOGIN_USE_GIT_FLOW=1
    #
    if [ "${ARTLOGIN_USE_GIT_FLOW:-0}" = "1" ]; then
        if command -v git-flow >/dev/null 2>&1; then
            artlogin_info "Initializing git-flow ..."
            yes '' | git flow init >/dev/null
        else
            artlogin_info "Warning: git-flow requested but command not found."
        fi
    fi


    # Initialize submodules by default.
    #
    # Disable with:
    #
    #   ARTLOGIN_INIT_SUBMODULES=0
    #
    if [ "${ARTLOGIN_INIT_SUBMODULES:-1}" = "1" ]; then
        artlogin_info "Initializing Git submodules ..."

        git submodule sync --recursive
        git submodule update --init --recursive
    fi
}


# ------------------------------------------------------------
# Data directory
# ------------------------------------------------------------


artlogin_setup_link()
{
    local target="$1"
    local link_name="$2"
    local variable_name="$3"

    # Empty means "do not create a symbolic link".
    if [ -z "$target" ]; then
        artlogin_info "$variable_name is empty; $link_name link is not created."
        return 0
    fi

    if [ ! -d "$target" ]; then
        artlogin_info "Warning: $variable_name does not exist:"
        echo "  $target"
        artlogin_info "$link_name link is not created."
        return 0
    fi

    if [ -L "$link_name" ]; then
        local current_target
        current_target="$(readlink "$link_name")"

        if [ "$current_target" = "$target" ]; then
            artlogin_info "$link_name already points to:"
            echo "  $target"
            return 0
        fi

        artlogin_info "Warning: $link_name already exists as a symbolic link:"
        echo "  $link_name -> $current_target"
        return 0
    fi

    if [ -e "$link_name" ]; then
        artlogin_info "Warning: $link_name already exists and is not a symbolic link."
        return 0
    fi

    ln -s "$target" "$link_name"

    artlogin_info "Created symbolic link:"
    echo "  $link_name -> $target"
}

artlogin_setup_directories()
{
    artlogin_setup_link \
        "${ART_DATA_DIR:-}" \
        "rawdata" \
        "ART_DATA_DIR" || return 1

    if [ -n "${ART_OUTPUT_DIR:-}" ]; then
        local user_output_dir="${ART_OUTPUT_DIR}/${ARTEMIS_USER}"

        if [ ! -d "$user_output_dir" ]; then
            artlogin_info "Creating user output directory:"
            echo "  $user_output_dir"

            if ! mkdir -p "$user_output_dir"; then
                artlogin_error "failed to create user output directory:"
                echo "  $user_output_dir" >&2
                return 1
            fi
        fi

        artlogin_setup_link \
            "$user_output_dir" \
            "output" \
            "ART_OUTPUT_DIR" || return 1
    else
        artlogin_info "ART_OUTPUT_DIR is empty; output link is not created."
    fi

    return 0
}


# ------------------------------------------------------------
# Existing user
# ------------------------------------------------------------

artlogin_use_existing_user()
{
    local userdir="$1"

    cd "$userdir" || return 1

    export ART_USER_FULLNAME
    export ART_USER_EMAIL

    ART_USER_FULLNAME="$(git config --local user.name 2>/dev/null || true)"
    ART_USER_EMAIL="$(git config --local user.email 2>/dev/null || true)"

    return 0
}


# ------------------------------------------------------------
# New user
# ------------------------------------------------------------

artlogin_create_user()
{
    local username="$1"
    local userdir="$2"
    local repos_url

    artlogin_info "user '$username' not found."

    if ! artlogin_yes_no "create new user?"; then
        artlogin_info "cancelled."
        return 1
    fi


    repos_url="$(repo_resolve_url)" || return 1

    echo
    artlogin_info "Repository:"
    echo "  $repos_url"

    artlogin_info "Destination:"
    echo "  $userdir"
    echo


    mkdir -p "$(dirname "$userdir")" || return 1


    artlogin_info "Cloning repository ..."

    local -a clone_args=("$repos_url" "$userdir")

    if [ -n "${REPO_BRANCH:-}" ]; then
        clone_args=(--branch "$REPO_BRANCH" "${clone_args[@]}")
    fi

    if ! git clone "${clone_args[@]}"; then
        artlogin_error "git clone failed."
        return 1
    fi


    cd "$userdir" || return 1


    artlogin_initialize_repository || return 1

    artlogin_setup_git_user || return 1

    artlogin_setup_directories || return 1

    echo
    echo "======================================"
    echo " New ARTEMIS user created"
    echo "======================================"
    echo
    echo "user:"
    echo "  $username"
    echo
    echo "work directory:"
    echo "  $userdir"
    echo

    return 0
}


# ------------------------------------------------------------
# Main common login function
# ------------------------------------------------------------

artlogin_common()
{
    local username="${1:-}"
    local userdir

    export ARTLOGIN_CREATED=0

    if [ -z "$username" ]; then
        artlogin_error "username is required."
        echo "usage: artlogin-nix <group> <username>" >&2
        return 1
    fi


    artlogin_check_environment || return 1


    userdir="${ART_ANALYSIS_DIR}/user/${username}"


    export ARTEMIS_USER="$username"
    export ARTEMIS_WORKDIR="$userdir"


    # --------------------------------------------------------
    # Existing user
    # --------------------------------------------------------

    if [ -d "$userdir" ]; then

        artlogin_use_existing_user "$userdir" || return 1

        artlogin_info "Using existing ARTEMIS work directory:"
        echo "  $ARTEMIS_WORKDIR"

        return 0
    fi


    # Something exists but is not a directory.
    if [ -e "$userdir" ]; then
        artlogin_error "path already exists but is not a directory:"
        echo "  $userdir" >&2
        return 1
    fi


    # --------------------------------------------------------
    # New user
    # --------------------------------------------------------

    artlogin_create_user "$username" "$userdir" || return 1

    export ARTLOGIN_CREATED=1

    return 0
}
