#!/bin/bash
set -x
cd "$(dirname "$(dirname "$(realpath "$0")")")"

LABELS=$1   # labelled domains that we care about final ranks for
VERTICES=$2 # the graph that PPR runs on
LIST=$3     # domain list to be intervened on with PPR
RANK_FILE=$4  # exp name for outputs
INVERT_PPR=$5 # 0 = vanilla PPR (boost domains in list), 1 = inversee PPR (demote domains in list)

num_domains=$(wc -l <"$VERTICES")

if [ "$LIST" != "-" ]; then
    java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.CreatePreferenceVector $VERTICES $LIST $LIST.bin $INVERT_PPR $num_domains
    ./src/script/webgraph_ranking/run_webgraph.sh it.unimi.dsi.law.rank.PageRankParallelGaussSeidel --preference-vector $LIST.bin --strongly --expand --mapped --threads 2 ./ranking/output/preference_up-t ./ranking/output/$RANK_FILE
else # Baseline
    ./src/script/webgraph_ranking/run_webgraph.sh it.unimi.dsi.law.rank.PageRankParallelGaussSeidel --expand --mapped --threads 2 ./ranking/output/preference_up-t ./ranking/output/$RANK_FILE
fi

java -cp target/cc-webgraph-0.1-SNAPSHOT-jar-with-dependencies.jar org.commoncrawl.webgraph.JoinSortRanks $VERTICES ./ranking/output/$RANK_FILE.ranks ./ranking/output/$RANK_FILE.ranks ./ranking/output/ranks/$RANK_FILE-ranks.txt
source ranking/filter_rank_output.sh $LABELS $RANK_FILE ./ranking/output/ranks/