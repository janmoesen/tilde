for file in ~/.bashfiles/{shell,commands,prompt,extra}; do
	[ -r "$file" ] && source "$file";
done;
unset file;
