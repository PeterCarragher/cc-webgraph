#!/bin/bash
set -x

awk 'BEGIN { FS="\t" } FNR==NR { strings[$0]; next } { for (string in strings) { if (index($2, string) != 0) { print $2 "," string } } }' bad_casinos.txt ../data/cc-main-2023-may-sep-nov-domain-vertices.txt > bad_casino_urls.csv
python3 get_matching_casino_urls.py

EDGES=../ranking/data/cc-main-2023-may-sep-nov-domain-edges.txt # the graph that PPR runs on
VERTICES=../ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt # the graph that PPR runs on
RANK_FILE=exp-scam-casino-discover
LIST=./cc_spam_casino_urls.csv

sort $LIST -o $LIST

num_domains=$(wc -l <"$VERTICES")
java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.CreatePreferenceVector $VERTICES $LIST $LIST.bin 0 $num_domains


# don't use transpose as we need to compute pagerank on a reversed edgelist
./src/script/webgraph_ranking/run_webgraph.sh it.unimi.dsi.law.rank.PageRankParallelGaussSeidel --preference-vector $LIST.bin --strongly --expand --mapped --threads 2 \
    ../ranking/output/preference_up ../ranking/output/$RANK_FILE
java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.JoinSortRanks $VERTICES ../ranking/output/$RANK_FILE.ranks ../ranking/output/$RANK_FILE.ranks ../ranking/output/$RANK_FILE.out

awk -F'\t' '{ if ($3 < 100000) { print $0 } }' ranking/output/$RANK_FILE.out > ranking/output/$RANK_FILE-top.out 
sort -k3,3n ranking/output/$RANK_FILE-top.out -o ranking/output/$RANK_FILE-top.out.sorted
awk -F'\t' '{ if ($3 < 100000) { print $5 } }' ../ranking/output/$RANK_FILE.out > ../ranking/data/preference_vectors/domain_lists/$RANK_FILE.domains.txt
sort ../ranking/data/preference_vectors/domain_lists/$RANK_FILE.domains.txt -o ../ranking/data/preference_vectors/domain_lists/$RANK_FILE.domains.txt

python3 multi_category_link_schemes_identification.py

../run_ppr.sh $LABELS $VERTICES \
    ./ranking/casinos/multi-domain-link-schemes-urls.csv exp-ls-multi_domain_atr 1