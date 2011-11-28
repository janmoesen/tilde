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
elif ! $dry_run mkdir -vp "$target_dir"; then
	echo "I cannot create a writable directory $target_dir";
	exit 1;
fi;

# Determine the absolute path to the source and target directories.
source_dir="$(cd "$(dirname "$0")" > /dev/null; pwd)";
$is_dry_run || target_dir="$(cd "$target_dir" > /dev/null; pwd)";

# Create the array of files to symlink. For now that means: everything starting
# with a dot, excluding ".", ".." and this repository's data.
printf -v GLOBIGNORE '%s:' "$source_dir"/{.,..,.git,.gitmodules};
source_files=("$source_dir"/.*);

# Check if any of the files already exist in the target directory, and if so,
# are not already the same as in this repository. Note that "file" can also
# mean "directory" here. Directories are compared recursively.
common_files=();
shopt -s dotglob;
for source in "${source_files[@]}"; do
	target="$target_dir/${source#$source_dir/}";
	if [ -e "$target" ]; then
		# If source and target point to the same file, it is OK to replace
		# the target.
		[ "$source" -ef "$target" ] && continue;

		# If the contents of the two files is the same, it is OK to replace
		# the target.
		diff -rq "$source" "$target" > /dev/null 2>&1 && continue;

		# If we got this far, it means we should not overwrite the target
		# file without confirmation.
		common_files+=("$source");
	fi;
done;

# Show the files that will be overwritten.
num_conflicts=${#common_files[@]};
if [ $num_conflicts -gt 0 ]; then
	backup_suffix=".tilde-$(date +'%Y%m%d-%H%M%S')";

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
	for source in "${common_files[@]}"; do
		target="$target_dir/${source#$source_dir/}";
		ls_labels+=("$lbl_yours" "$lbl_tilde");
		ls_files+=("$target" "$source");
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

	# Make sure the user knows that their will be dataloss.
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
for source in "${common_files[@]}"; do
	target="$target_dir/${source#$source_dir/}";
	$dry_run mv -v "$target" "$target$backup_suffix";
done;

# Install Tilde by symlinking the files from the Tilde repository.
has_created_links=false;
for source in "${source_files[@]}"; do
	# Determine the directory for our symlinks, relative to the home directory if
	# possible. (So "/home/janmoesen/.bashrc" links to "src/tilde/.bashrc" rather
	# than "/home/janmoesen/src/tilde/.bashrc".)
	relative_source="${source#$target_dir/}";
	target="$target_dir/${source#$source_dir/}";
	if [ -L "$target" -a "$(readlink "$target")" = "$relative_source" ]; then
		continue;
	fi;
	$dry_run rm -rf "$target" &&
	$dry_run ln -vs "$relative_source" "$target";
	has_created_links=true;
done;
$has_created_links || echo "All of Tilde's files were symlinked already.";
echo 'Done.';

