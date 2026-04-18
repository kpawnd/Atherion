#!/bin/bash

run_step_interactive() {
    local step_name="$1"
    shift

    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    print_info "$step_name"

    if "$@"; then
        print_ok "$step_name completed"
    else
        FAILED_STEPS=$((FAILED_STEPS + 1))
        print_warn "$step_name failed, continuing"
    fi
}

retry_with_dependency_fix() {
    local step_name="$1"
    local log_file="$2"
    shift 2

    if ! declare -F attempt_dependency_repair >/dev/null 2>&1; then
        return 1
    fi

    if ! attempt_dependency_repair "$log_file"; then
        return 1
    fi

    print_info "Retrying step after dependency repair: $step_name"

    : > "$log_file"
    "$@" >"$log_file" 2>&1 &
    local pid=$!
    spinner_wait "$pid" "$step_name (retry)"
}

run_step() {
    local step_name="$1"
    shift
    local log_file
    local status

    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    log_file="$(mktemp)"

    "$@" >"$log_file" 2>&1 &
    local pid=$!
    spinner_wait "$pid" "$step_name"
    status=$?

    if [[ "$status" -ne 0 ]]; then
        retry_with_dependency_fix "$step_name" "$log_file" "$@"
        status=$?
    fi

    if [[ "$status" -eq 0 ]]; then
        print_ok "$step_name completed"
    else
        FAILED_STEPS=$((FAILED_STEPS + 1))
        print_warn "$step_name failed, continuing"
        if [[ -s "$log_file" ]]; then
            print_warn "Last output for failed step:"
            tail -n 25 "$log_file"
        fi
    fi

    rm -f "$log_file" >/dev/null 2>&1 || true
}
