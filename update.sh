#!/bin/bash
BIN_DIR=$(dirname "$(readlink -f "$0")")

_usage() {
  echo "$0 usage:" && grep " .)\\ #" $0 | sed -e 's/\(.\)) #/-\1/g'
  exit 0;
}

_update() {
  # $1: URL of file
  # $2: File name of command
  # $3: True/False for add command to gitignore
  # $4: Flag check is install by external file
  if [ "$NEW_ONLY" = true ] && [ -f $BIN_DIR/$2  ]; then
    return
  fi
  if [ "$3" = true ]; then
    grep -qr "$2" $BIN_DIR/.gitignore || echo "/$2" >> .gitignore
  fi
  if [ "$4" = true ]; then
    local temp=$(mktemp)
    curl -SL $1 -o $temp && source $BIN_DIR/external/$2 && chmod +x $BIN_DIR/$2
    rm -rf $temp
  else
    curl -SL $1 -o $BIN_DIR/$2 && chmod +x $BIN_DIR/$2
  fi
}

_update_github_raw() {
  # $1: Repository string on Github
  # $2: Branch of file in Git repository
  # $3: Path of file in Git repository
  # $4: Output file name of command
  test -z "$2" && branch="master" || branch=$2
  test -z "$3" && git_path=${1##*/} || git_path=$3
  test -z "$4" && file_name=${git_path##*/} || file_name=$4
  echo "Checking $file_name"
  _update "https://raw.githubusercontent.com/$1/$branch/$git_path" "$file_name"
}

_update_github_release() {
  # $1: Repository string on Github
  # $2: Version of Github Release
  # $3: File name in Github Release URLs
  # $4: Output file name of command
  # $5: Flag check is install by external file
  echo "Checking $4"
  test -z "$2" && version=$(curl -sSL https://api.github.com/repos/$1/releases/latest | grep -Po "tag_name\": \"(\K.*)(?=\",)") || version=$2
  _update "https://github.com/$1/releases/download/$version/$(eval "echo $3")" "$4" true "$5"
}

_run() {
  # Update command by view RAW of file
  tail -n +2 $BIN_DIR/data_raw.csv | grep -is ",$PACKAGE" | while IFS=, read -r repo branch git_path file_name; do
    _update_github_raw "$repo" "$branch" "$git_path" "$file_name"
  done

  # Update command by get release file
  tail -n +2 $BIN_DIR/data_release.csv | grep -is ",$PACKAGE" | while IFS=, read -r repo version asset_file file_name external_install; do
    _update_github_release "$repo" "$version" "$asset_file" "$file_name" "$external_install"
  done
}

while getopts ":hns:" arg; do
  case $arg in
    n) # Update only new command
      NEW_ONLY=true
      ;;
    h) # Display help
      _usage
      ;;
    s) # Only one specific tool
      PACKAGE=$OPTARG
      ;;
  esac
done

_run
