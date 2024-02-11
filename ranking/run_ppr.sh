#!/bin/bash
cd "$(dirname "$(dirname "$0")")"

LABELS=$1   # labelled domains that we care about final ranks for
VERTICES=$2 # the graph that PPR runs on
LIST=$3     # domain list to be intervened on with PPR
RANK_FILE=$4
INVERT_PPR=$5

num_domains=$(wc -l <"$VERTICES")
java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.CreatePreferenceVector $VERTICES $LIST $LIST.bin $INVERT_PPR $num_domains
./src/script/webgraph_ranking/run_webgraph.sh it.unimi.dsi.law.rank.PageRankParallelGaussSeidel --preference-vector $LIST.bin --strongly --expand --mapped --threads 2 ./ranking/output//preference_up-t ../output/$RANK_FILE
java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.JoinSortRanks $VERTICES ./ranking/output/$RANK_FILE.ranks ./ranking/output/$RANK_FILE.ranks ./ranking/output/ranks/$RANK_FILE.out

filter_giant_file() {
    local labeled_list=$1
    local giant_file=$2
    local output_file=$3
    local return_urls=$4
    local reverse_urls=$5
    local giant_url_col=$6

    awk -v return_urls="$return_urls" -v reverse="$reverse_urls" -v col="$giant_url_row" \
        'NR==FNR { 
            url = $1; 
            split(url, parts, "."); 
            reverse_url = parts[length(parts)]; 
            for (i=length(parts)-1; i>0; i--) 
                reverse_url = reverse_url "." parts[i]; 
            urls[reverse_url] = 1
            next 
        } 
        {
            url = $col;
            if (url in urls) {
                if (return_urls == 1) {
                    if (reverse == 1) {
                        split(url, parts, "."); 
                        reverse_url = parts[length(parts)]; 
                        print url;
                    } else {
                        print url
                    }
                } else {
                    print $0;
                }
            }
        }' FS=, $labeled_list FS='\t' $giant_file >$output_file
}

filter_giant_file $LABELS ./ranking/output/ranks/$RANK_FILE.out ./ranking/output/ranks/$RANK_FILE.label_only.out 0 0 5
