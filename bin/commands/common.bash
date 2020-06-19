#!/bin/bash
set -euo pipefail
export LC_ALL=C
export LANG=C

is_simlink() {
  local path=$1
  test -L $path
}

is_valid_simlink() {
  local path=$1
  test -L $path && test -e $path
}

is_broken_simlink() {
  local path=$1
  is_simlink $path && ! is_valid_simlink $path
}

isola2path() {
  local isola_str=$1
  echo ${ISOLA_ROOT}/projects/${isola_str//:/\/}
}

path2isola() {
  local path=$1
  local ps=(${path//\// })
  local project=${ps[@]:(-3):1}
  local name=${ps[@]:(-2):1}
  local version=${ps[@]:(-1):1}
  echo ${project}:${name}:${version}
}

resolve_isola_simlink() {
  local isola_str=$1
  local path=$(cd $(isola2path $isola_str) && pwd -P)
  path2isola $path
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
  if [[ "${#tokens[@]}" == 1 ]]; then
    # project
    local project="${tokens[0]}"
    validate_project $project
    echo $project
  elif [[ "${#tokens[@]}" == 2 ]]; then
    # project:name
    local project="${tokens[0]}"
    local name="${tokens[1]}"
    validate_name $project $name
    echo $project $name
  elif [[ "${#tokens[@]}" == 3 ]]; then
    # project:name:version
    local project="${tokens[0]}"
    local name="${tokens[1]}"
    local version="${tokens[2]}"
    validate_version $project $name $version
    echo $project $name $version
  else
    echo "Isola Parse Error: isola format '$isola_str' is invalid." >&2
    echo "## Isola format must be 'project[:name[:version]]'" >&2
    exit 1
  fi
}

get_isola_dir() {
  if [[ "$#" == 2 ]]; then
    # project:name
    local project=$1
    local name=$2
    echo ${ISOLA_ROOT}/projects/${project}/${name}/latest
  elif [[ "$#" == 3 ]]; then
    # project:name:version
    local project=$1
    local name=$2
    local version=$3
    echo ${ISOLA_ROOT}/projects/${project}/${name}/${version}
  else
    echo "Internal Error." >&2
    exit 1
  fi
}

get_isola_dir_from_str() {
  set -e
  local isola_str=$1
  local tokens
  tokens=($(parse_isola $isola_str))
  if [[ "${#tokens[@]}" == 2 || "${#tokens[@]}" == 3 ]]; then
    get_isola_dir "${tokens[@]}"
  else
    echo "Isola '$isola_str' must include name." >&2
    echo "## Isola format must be 'project:name[:version]'" >&2
    exit 1
  fi
}

get_project_list() {
  find ${ISOLA_ROOT}/projects -mindepth 1 -maxdepth 1 -printf "%f\n" | sort
}

get_name_list() {
  local project=$1
  find ${ISOLA_ROOT}/projects/${project} -mindepth 1 -maxdepth 1 -printf "${project}:%f\n" | sort
}

get_version_list() {
  local project=$1
  local name=$2
  find ${ISOLA_ROOT}/projects/${project}/${name} -mindepth 1 -maxdepth 1 -printf "${project}:${name}:%f\n" | sort
}

get_version_list_wo_simlink() {
  local project=$1
  local name=$2
  find ${ISOLA_ROOT}/projects/${project}/${name} -mindepth 1 -maxdepth 1 -type d -printf "${project}:${name}:%f\n" | sort
}

get_isola_list() {
  set -e
  if [[ "$#" == 0 ]]; then
    get_project_list
  else
    local isola_str=$1
    local tokens
    tokens=($(parse_isola $isola_str))
    if [[ "${#tokens[@]}" == 1 ]]; then
      # project
      get_name_list "${tokens[@]}"
    elif [[ "${#tokens[@]}" == 2 ]]; then
      # project:name
      get_version_list "${tokens[@]}"
    elif [[ "${#tokens[@]}" == 3 ]]; then
      # project:name:version
      echo "$(IFS=':'; echo "${tokens[*]}")"
    else
      echo "Internal Error." >&2
      exit 1
    fi
  fi
}

get_rec_project_list() {
  for project in $(get_project_list); do
    get_rec_name_list $project
  done
}

get_rec_name_list() {
  local project=$1
  for name in $(get_name_list $project | cut -d ':' -f 2); do
    get_version_list $project $name
  done
}

get_rec_isola_list() {
  set -e
  if [[ "$#" == 0 ]]; then
    get_rec_project_list
  else
    local isola_str=$1
    local tokens
    tokens=($(parse_isola $isola_str))
    if [[ "${#tokens[@]}" == 1 ]]; then
      # project
      get_rec_name_list "${tokens[@]}"
    elif [[ "${#tokens[@]}" == 2 ]]; then
      # project:name
      get_version_list "${tokens[@]}"
    elif [[ "${#tokens[@]}" == 3 ]]; then
      # project:name:version
      echo "$(IFS=':'; echo "${tokens[*]}")"
    else
      echo "Internal Error." >&2
      exit 1
    fi
  fi
}

relink_latest_simlink() {
  local project=$1
  local name=$2
  local simlink_path=$(isola2path ${project}:${name}:latest)
  local isolas=($(get_version_list_wo_simlink $project $name))
  if [[ "${#isolas[@]}" == 0 ]]; then
    rm -f $simlink_path
  else
    local latest_isola=${isolas[@]:(-1):1}
    ln -sfn $(isola2path $latest_isola) $simlink_path
  fi
}

cleanup_projects() {
  for project in $(get_project_list); do
    for name in $(get_name_list $project | cut -d ':' -f 2); do
      for version in $(get_version_list $project $name | cut -d ':' -f 3); do
        local path=$(isola2path ${project}:${name}:${version})
        # if symlink 'latest' is broken, try to fix it. Otherwise just remove it.
        if is_broken_simlink $path; then
          if [[ "${version}" == latest ]]; then
            relink_latest_simlink $project $name
          else
            rm -f $path
          fi
        fi
      done
      # if 'name' is empty, remove it
      if [[ -z "$(get_version_list $project $name)" ]]; then
        rm -rf ${ISOLA_ROOT}/projects/${project}/${name}
      fi
    done
    # if 'project' is empty, remove it
    if [[ -z "$(get_name_list $project)" ]]; then
      rm -rf ${ISOLA_ROOT}/projects/${project}
    fi
  done
}
