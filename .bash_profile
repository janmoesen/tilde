for file in ~/.bash/{shell,commands,prompt,extra}; do
	[ -r "$file" ] && source "$file";
done;
unset file;
