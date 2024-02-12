#!/bin/bash
set -x
cd "$(dirname "$(dirname "$(realpath "$0")")")"

LABELS=../data/attributes.csv # labelled domains that we care about final ranks for 
VERTICES=./ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt # the graph that PPR runs on


./ranking/run_ppr.sh $LABELS $VERTICES - exp-baseline 0

./ranking/run_ppr.sh $LABELS $VERTICES \
    ./ranking/data/preference_vectors/domain_lists/rel_domains.txt exp-rel-ppr 0

./ranking/run_ppr.sh $LABELS $VERTICES \
    ./ranking/data/preference_vectors/domain_lists/unrel_domains.txt exp-unrel-ppr-down 1

./ranking/run_ppr.sh $LABELS $VERTICES \
    ./ranking/data/preference_vectors/domain_lists/link_scheme_domains.txt exp-ls-ppr-down 1