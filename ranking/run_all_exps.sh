#!/bin/bash
cd "$(dirname "$(dirname "$0")")"

LABELS=../data/attributes.csv # labelled domains that we care about final ranks for 
VERTICES=./ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt # the graph that PPR runs on


./run_ppr.sh $LABELS $VERTICES \
    ./ranking/data/preference_vectors/domain_lists/link_scheme_domains.txt exp-ls-ppr-down 1


# ./run_ppr.sh $LABELS $VERTICES \
#     ../data/preference_vectors/domain_lists/link_scheme_domains.txt exp-ls-ppr-down 1