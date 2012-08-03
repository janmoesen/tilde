#!/bin/bash
#
# "Install" the files from the Tilde repository by symlinking them from the
# home directory.

# Show a quick help summary.
function usage {
	echo "Usage: $(basename "$0") [ --dry-run ] [ --prefix=$HOME ]";
}

# Parse the command-line arguments.
is_dry_run=false;
dry_run=;
target_dir="$HOME";
while (($#)); do
	case "$1" in
		--dry-run)
			is_dry_run=true;
			dry_run=echo;
			;;
		--prefix=*)
			target_dir="${1#--prefix=}";
			;;
		--help)
			usage;
			exit 0;
			;;
		*)
			[ "$1" = '--' ] && shift;
			if (($#)); then
				# There are unexpected arguments.
				usage;
				exit 1;
			fi;
	esac;
	shift;
done;
if [ "$target_dir" = '~' ]; then
	target_dir=~;
fi;
if [[ "$target_dir" =~ ^/+$ ]]; then
	target_dir=/;
elif [[ "$target_dir" =~ ^(.*[^/]+)/+$ ]]; then
	target_dir="${BASH_REMATCH[1]}";
fi;

$is_dry_run && echo 'Dry run mode. Not actually executing anything.';

# Make sure the target directory is OK.
if [ -z "$target_dir" ]; then
	echo "The target directory prefix is empty.";
	exit 1;
elif [ "$target_dir" = '/' ]; then
	echo "I refuse to install into the root directory.";
	exit 1;
elif [ -d "$target_dir" ]; then
	if ! [ -w "$target_dir" ]; then
		echo "$target_dir is not a writable directory.";
		exit 1;
	fi;
elif [ -e "$target_dir" ]; then
	echo "$target_dir exists, but is not a writable directory.";
	exit 1;
elif ! $dry_run mkdir -p "$target_dir"; then
	echo "I cannot create a writable directory $target_dir";
	exit 1;
fi;

# Determine the absolute path to the source and target directories.
source_dir="$(cd "$(dirname "$0")" > /dev/null; pwd)";
$is_dry_run || target_dir="$(cd "$target_dir" > /dev/null; pwd)";

# Create the array of files to symlink.
source_files=();
ignored_files=(
	.gitignore
	COPYING
	README.md
	install.sh
);
while read -d $'\0' file; do
	file="${file#./}";
	for ignored_file in "${ignored_files[@]}"; do
		[ "$file" = "$ignored_file" ] && continue 2;
	done;
	source_files+=("$file");
done < <(
	cd "$source_dir";
	# If Git is available, use "git ls-tree" to get a list of all files. If
	# Git is not available, resort to "find", which might yield more results
	# because of untracked files.
	git ls-tree --name-only -r -z HEAD 2> /dev/null ||
		find . -name '.git' -prune -o -type f -print0
);

# Check if any of the files already exist in the target directory, and if so,
# are not already the same as in this repository. Note that "file" can also
# mean "directory" here. Directories are compared recursively.
common_files=();
for file in "${source_files[@]}"; do
	if [ -L "$target_dir/$file" -o -e "$target_dir/$file" ]; then
		# If source and target point to the same file, it is OK to replace
		# the target.
		[ "$source_dir/$file" -ef "$target_dir/$file" ] && continue;

		# If the contents of the two files is the same, it is OK to replace
		# the target.
		diff -rq "$source_dir/$file" "$target_dir/$file" > /dev/null 2>&1 && continue;

		# If we got this far, it means we should not overwrite the target
		# file without confirmation.
		common_files+=("$file");
	fi;
done;

# Show the files that will be overwritten.
backup_suffix=".tilde-$(date +'%Y%m%d-%H%M%S')";
num_conflicts=${#common_files[@]};
if [ $num_conflicts -gt 0 ]; then

	# Warn the user about potential dataloss.
	if [ $num_conflicts -eq 1 ]; then
		tput setaf 3;
		printf 'WARNING: there is a file of yours that conflicts with Tilde.';
		tput sgr0;
		echo " Your file will be given the suffix $backup_suffix and" \
			"replaced by a symlink to Tilde's:";
	else
		tput setaf 3;
		printf 'WARNING: there are files of yours that conflict with Tilde.';
		tput sgr0;
		echo " Your files will be given the suffix $backup_suffix and" \
			"replaced by symlinks to Tilde's:" ;
	fi;

	lbl_yours=" Yours:";
	lbl_tilde=" Tilde:";
	if [ -t 1 ]; then
		# Colorize the output if stdout is not piped.
		lbl_yours="$(tput setaf 1)$lbl_yours";
		lbl_tilde="$(tput setaf 2)$lbl_tilde";
	fi;
	ls_labels=();
	ls_files=();
	for file in "${common_files[@]}"; do
		ls_labels+=("$lbl_yours" "$lbl_tilde");
		ls_files+=("$target_dir/$file" "$source_dir/$file");
	done;

	# "paste" merges lines from two files. Using process substitution, we give
	# it two files: one with a "Yours:" line and a "Tilde:" for each file, and
	# one with the "ls" output for your target file and Tilde's file. Use "-f"
	# to ensure that "ls" does not sort the files.
	paste -d ' ' \
		<(printf '%s\n' "${ls_labels[@]}") \
		<(ls -fdalF "${ls_files[@]}");
	tput sgr0;
	echo;

	# Make sure the user confirms his/her existing files will be renamed.
	read -p 'Would you like to continue? If so, please type "yes": ';
	case "$(tr '[:upper:]' '[:lower:]' <<< "$REPLY")" in
		'yes')
			# OK, the installation will proceed below.
			;;
		'n'|'no')
			exit;
			;;
		'y')
			echo 'For your own safety, you have to type "yes" in full.';
			echo 'Installation aborted.';
			exit 1;
			;;
		*)
			[ -z "$REPLY" ] && echo;
			echo 'Invalid answer; presumed "no". Installation aborted.';
			exit 1;
	esac;
fi;

# Rename the conflicting files.
for file in "${common_files[@]}"; do
	$dry_run mv "$target_dir/$file" "$target_dir/$file$backup_suffix";
done;

# Older installations symlinked the entire .bash directory. Now we symlink the
# files themselves, so we need to create that directory and symlink the separate
# files when upgrading from one of those older versions.
bash_dir="$target_dir/.bash";
if [ -d "$bash_dir" -a -L "$bash_dir" ]; then
	tput setaf 3;
	echo 'This appears to be an upgrade from an older version of Tilde.';
	tput sgr0;
	echo "I will rename the $bash_dir symlink to $bash_dir$backup_suffix" \
		'and recreate it as a directory.';
	echo "Next, I will create symlinks to all files in Tilde's .bash" \
		'directory. If you experience any problems after the upgrade,' \
		'please file an issue on GitHub:';
	echo 'https://github.com/janmoesen/tilde';
	echo;
	$dry_run mv "$bash_dir" "$bash_dir$backup_suffix";

	# Add the extra files in .bash to the array of source files to symlink.
	for bash_file in "$source_dir"/.bash/*; do
		bash_file="${bash_file#$source_dir/}";
		for file in "${source_files[@]}"; do
			[ "$bash_file" = "$file" ] && continue 2;
		done;
		for file in "${ignored_files[@]}"; do
			[ "$bash_file" = "$file" ] && continue 2;
		done;
		source_files=("$bash_file" "${source_files[@]}");
	done;
fi;

# Determine the relative source directory for the symlinks.
IFS=/ read -a source_dir_parts <<< "$source_dir";
IFS=/ read -a target_dir_parts <<< "$target_dir";
num_common_directories=0;
for ((i = 1; i < ${#target_dir_parts[@]}; i++)); do
	if [ "${target_dir_parts[$i]}" != "${source_dir_parts[$i]}" ]; then
		break;
	fi;
	let num_common_directories++;
done;

if [ $num_common_directories -eq 0 ]; then
	relative_source_dir="$source_dir";
else
	relative_source_dir_parts=();
	for ((i = 0; i < ${#target_dir_parts[@]} - 1 - num_common_directories; i++)); do
		relative_source_dir_parts+=('..');
	done;
	for ((i = num_common_directories + 1; i < ${#source_dir_parts[@]}; i++)); do
		relative_source_dir_parts+=("${source_dir_parts[$i]}");
	done;
	printf -v relative_source_dir '%s/' "${relative_source_dir_parts[@]}";
	relative_source_dir="${relative_source_dir%/}";
fi;

# Install Tilde by symlinking the files from the Tilde repository.
has_created_links=false;
for file in "${source_files[@]}"; do
	target="$target_dir/$file";
	target_container_dir="$(dirname "$target")";
	if ! [ -d "$target_container_dir" ]; then
		$dry_run mkdir -p "$target_container_dir" || continue;
	fi;

	# Determine the target for our symlinks, relative to the installation
	# directory if possible. (So "/home/janmoesen/.bashrc" links to
	# "src/tilde/.bashrc" rather than "/home/janmoesen/src/tilde/.bashrc" when
	# installing from "/home/janmoesen/src/tilde".)
	relative_source="$relative_source_dir";
	if [ "${relative_source:0:1}" != '/' ] && [[ "$file" =~ / ]]; then
		# If the file is not in the repository's root, we need to go up
		# additional levels for the relative path.
		IFS=/ read -a file_dir_parts <<< "$(dirname "$file")";
		for ((i = 0; i < ${#file_dir_parts[@]}; i++)); do
			relative_source="../$relative_source";
		done;
	fi;
	relative_source="$relative_source/$file";
	if ! [ -L "$target" ]; then
		$dry_run ln -vs "$relative_source" "$target";
		has_created_links=true;
	fi;
done;
$has_created_links || echo "All of Tilde's files were symlinked already.";
echo 'Done.';

