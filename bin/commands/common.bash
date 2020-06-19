#!/bin/bash

parse_error_and_exit() {
  local isola_str=$1
  echo "Isola Parse Error: isola format '$isola_str' is invalid." >&2
  echo "## Isola format must be 'project:name[:version]'" >&2
  exit 1
}

validate_project() {
  local project=$1
  if [ ! -e ${ISOLA_ROOT}/projects/${project} ]; then
    echo "No project '$project' exists." >&2
    exit 1
  fi
}

validate_name() {
  local project=$1
  local name=$2
  validate_project $project
  if [ ! -e ${ISOLA_ROOT}/projects/${project}/${name} ]; then
    echo "No name '$name' exists in Isola project '$project'." >&2
    exit 1
  fi
}

validate_version() {
  local project=$1
  local name=$2
  local version=$3
  validate_project $project
  validate_name $project $name
  if [ ! -e ${ISOLA_ROOT}/projects/${project}/${name}/${version} ]; then
    echo "No version '$version' exists in Isola '${project}:${name}'." >&2
    exit 1
  fi
}

parse_isola() {
  local isola_str=$1
  local tokens=(${isola_str//:/ })
  if [[ "${#tokens[@]}" == 2 ]]; then
    # project:name
    local project="${tokens[0]}"
    local name="${tokens[1]}"
    validate_name $project $name
    echo ${ISOLA_ROOT}/projects/${project}/${name}/latest
  elif [[ "${#tokens[@]}" == 3 ]]; then
    # project:name:version
    local project="${tokens[0]}"
    local name="${tokens[1]}"
    local version="${tokens[2]}"
    validate_version $project $name $version
    echo ${ISOLA_ROOT}/projects/${project}/${name}/${version}
  else
    parse_error_and_exit $isola_str
  fi
}
