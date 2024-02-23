#!/bin/bash
set -x
cd "$(dirname "$(dirname "$(realpath "$0")")")"

# remove just the link schemes: https://arxiv.org/abs/2401.02379
# LS_LIST=ranking/data/preference_vectors/domain_lists/link_scheme_domains.txt
LS_LIST=ranking/data/preference_vectors/domain_lists/cc_link_scheme_domains.txt.domains.final

# remove link schemes + link spam discovered domains with high ATR score: https://dl.acm.org/doi/10.1145/3366424.3385773, http://i.stanford.edu/~kvijay/krishnan-raj-airweb06.pdf
LS_ATR_LIST=ranking/data/preference_vectors/domain_lists/cc_link_scheme_atr_domains_rank_sorted.txt # only take the top 1000
head -n 1000 ranking/output/exp-ls-atr-discover-top.out.sorted |  awk -F'\t' ' { print $5 }' > $LS_ATR_LIST.top1k

# combined
COMBINED_DOMAINS=ranking/data/preference_vectors/domain_lists/cc_link_schemes_atr_combined_domains.txt
cat $LS_LIST $LS_ATR_LIST.top1k > $COMBINED_DOMAINS

# multi-domain/home/pcarragh/dev/link_scheme_removal/cc-webgraph/ranking/
MULTI_DOMAIN_ATR_LIST=ranking/output/exp-multi-domain-casino-discover-top.out.sorted # only take the top 1000
head -n 20000 $MULTI_DOMAIN_ATR_LIST |  awk -F'\t' ' { print $5 }' > $MULTI_DOMAIN_ATR_LIST.top20k

MULTI_COMBINED=ranking/data/preference_vectors/domain_lists/cc_multi_domain_link_schemes_atr_20k.txt
cat $COMBINED_DOMAINS $MULTI_DOMAIN_ATR_LIST.top20k > $MULTI_COMBINED

# get node ID lists
VERTICES=./ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt
EDGES=./ranking/data/cc-main-2023-may-sep-nov-domain-edges.txt
LABELS=../data/attributes.csv # labelled domains that we care about final ranks for 

fetch_vertex_ids() {
    local domain_list=$1
    local id_list=$2
    local output_file=$3
    awk 'NR==FNR { 
            urls[$1] = 1
            next 
        } 
        {
            if ($2 in urls) {
                print $1;
            }
        }' FS=, "$domain_list" FS='\t' "$id_list" > "$output_file"
    sort -n "$output_file" -o "$output_file"
}

remove_edges_with_source_id() {
    local id_list=$1
    local edge_list=$2
    local output_file=$3
    awk 'NR==FNR { 
            ids[$1] = 1
            next
        } 
        {
            if (!($1 in ids) && !($2 in ids)) {
                print $0;
            }
        }' FS='\t' "$id_list" FS='\t' "$edge_list" > "$output_file"
}

run_edge_removal_exp() {
    local exp_name=$1
    local vertex_list=$2

    fetch_vertex_ids $vertex_list $VERTICES $vertex_list.ids
    remove_edges_with_source_id $vertex_list.ids $EDGES $EDGES.$exp_name
    gzip $EDGES.$exp_name
    rm -rf ranking/output/$exp_name/ && mkdir ranking/output/$exp_name/
    ./src/script/webgraph_ranking/process_webgraph.sh $exp_name ./ranking/data/cc-main-2023-may-sep-nov-domain-vertices-copy.txt.gz $EDGES.$exp_name.gz ./ranking/output/$exp_name/
    gzip -d ranking/output/$exp_name/$exp_name-ranks.txt.gz
    source ranking/filter_rank_output.sh $LABELS $exp_name ./ranking/output/$exp_name/
}

run_edge_removal_exp ls_filtered $LS_LIST
run_edge_removal_exp ls_atr_filtered $LS_ATR_LIST.top1k
run_edge_removal_exp ls_combined_filtered $COMBINED_DOMAINS
run_edge_removal_exp ls_multi_domain_atr $MULTI_DOMAIN_ATR_LIST.top20k
run_edge_removal_exp ls_multi_domain_atr_combined $MULTI_COMBINED

# TODO: bow-tie model
# remove only the backlinkers that do not have links from the center (left side of bow-tie model)

