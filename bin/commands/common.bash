#!/bin/bash

parse_isola() {
  local isola_str=$1
  local tokens=(${isola_str//:/ })
  if [[ "${#tokens[@]}" == 2 ]]; then
    # project:name
    local project="${tokens[0]}"
    local name="${tokens[1]}"
    echo ${ISOLA_ROOT}/projects/${project}/${name}/latest
  elif [[ "${#tokens[@]}" == 3 ]]; then
    # project:name:version
    local project="${tokens[0]}"
    local name="${tokens[1]}"
    local version="${tokens[2]}"
    echo ${ISOLA_ROOT}/projects/${project}/${name}/${version}
  else
    echo "Isola Parse Error: isola format '$isola_str' is invalid." >&2
    echo "## Isola format must be 'project:name[:version]'" >&2
    exit 1
  fi
}
