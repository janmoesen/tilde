#!/bin/bash
#
# Get the introductory paragraph from a Wikipedia article using the inimitable
# David Leadbeater's Wikipedia-over-DNS service.
#
# See https://dgl.cx/wikipedia-dns

query="$*";
domain="${query// /_}.wp.dg.cx";
answer="$(dig +short -t txt "$domain" | perl -p -e 's/\\([0-9]*)/chr($1)/eg')";
answer="${answer:1}";

while [ -n "$answer" ]; do
	    chunk_length=255;
	    [ "${#answer}" -lt 256 ] && chunk_length=$((${#answer} - 1));
	    text="${text}${answer:0:$chunk_length}";
	    answer="${answer:$(($chunk_length + 3))}";
done;

echo "$text";
