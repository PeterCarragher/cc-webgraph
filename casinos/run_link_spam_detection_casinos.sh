#!/bin/bash
set -x
cd "$(dirname "$(dirname "$(realpath "$0")")")"

EDGES=./ranking/data/cc-main-2023-may-sep-nov-domain-edges.txt # the graph that PPR runs on
VERTICES=./ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt # the graph that PPR runs on
# LIST=./ranking/data/preference_vectors/domain_lists/link_scheme_domains.txt
# RANK_FILE=exp-scam-casino-discover
# LIST=./casinos/bad_casino_urls_filtered.csv

RANK_FILE=exp-multi-domain-casino-discover
LIST=./casinos/multi-domain-link-schemes-urls-clean.csv

sort $LIST -o $LIST

num_domains=$(wc -l <"$VERTICES")
java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.CreatePreferenceVector $VERTICES $LIST $LIST.bin 0 $num_domains


# don't use transpose as we need to compute pagerank on a reversed edgelist
./src/script/webgraph_ranking/run_webgraph.sh it.unimi.dsi.law.rank.PageRankParallelGaussSeidel --preference-vector $LIST.bin --strongly --expand --mapped --threads 2 \
    ./ranking/output/preference_up ./ranking/output/$RANK_FILE
java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.JoinSortRanks $VERTICES ./ranking/output/$RANK_FILE.ranks ./ranking/output/$RANK_FILE.ranks ./ranking/output/$RANK_FILE.out

awk -F'\t' '{ if ($3 < 100000) { print $0 } }' ranking/output/$RANK_FILE.out > ranking/output/$RANK_FILE-top.out 
sort -k3,3n ranking/output/$RANK_FILE-top.out -o ranking/output/$RANK_FILE-top.out.sorted
awk -F'\t' '{ if ($3 < 100000) { print $5 } }' ./ranking/output/$RANK_FILE.out > ./ranking/data/preference_vectors/domain_lists/$RANK_FILE.domains.txt
sort ./ranking/data/preference_vectors/domain_lists/$RANK_FILE.domains.txt -o ./ranking/data/preference_vectors/domain_lists/$RANK_FILE.domains.txt
# No need for any of this since we can just use the un-transposed BVGraph...
# awk -F'\t' '{ print $2 "\t" $1 }' $EDGES.txt > "$EDGES"-reversed.txt
# sort -k1,1n -k2,2n "$EDGES"-reversed.txt -o "$EDGES"-reversed.txt
# gzip "$EDGES"-reversed.txt
# mv "$EDGES"-reversed.txt.gz ./ranking/data/reversed-edgelist/part-1.gz
