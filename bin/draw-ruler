#!/bin/bash

# Draw a ruler across the screen. By default, it displays the column number of
# the 1st, 11th, 21st, … column, and a marker on every 5 in between. You can
# also specify a custom string to draw as the first parameter. Every "x" in the
# string will be replaced by the column number.

# The string to repeat for the entire line. The letter "x" marks the start of
# the column number. Other characters are printed as they are.
str="${1:-x...·.....}";

num_columns="$(tput cols)";
curr_column=1;
while [ $curr_column -le $num_columns ]; do
	char="${str:$(((curr_column - 1) % ${#str})):1}";
	if [ "$char" = 'x' ]; then
		echo -n "$curr_column";
		let curr_column+=${#curr_column};
	else
		echo -n "$char";
		let curr_column++;
	fi;
done;
echo;
