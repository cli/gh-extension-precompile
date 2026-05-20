#! /bin/bash
# Assorted color utilities for build_and_release.sh.

# Make text orange.
orange () {
  printf "\e[33m%s\e[0m" "$1"
}

# Make text red.
red () {
  printf "\e[31m%s\e[0m" "$1"
}

# Make text green.
green () {
  printf "\e[32m%s\e[0m" "$1"
}

# Make text blue.
blue () {
  printf "\e[34m%s\e[0m" "$1"
}

# Annotate text with a blue [...].
info () {
  printf "[$(blue ...)] %s\n" "$1"
}

# Annotate text with a green [✔].
success () {
  printf "[$(green '✔ ')] %s\n" "$1"
}

# Annotate text with an orange [!!!] and send it to stderr.
warn () {
  printf "[$(orange !!!)] %s\n" "$1" >&2
}

# Annotate text with a red [✗] and send it to stderr.
error () {
  printf "[ $(red '✗') ] %s\n" "$1" >&2
}

# Annotate text with a red [✗] and send it to stderr,
# then return the specified non-zero error code to kill the program.
# Defaults to error code 1 if not provided.
fail () {
  error "$1"
  return "${2:-1}"
}
