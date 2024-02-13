#!/bin/bash
set -x
cd "$(dirname "$(dirname "$(realpath "$0")")")"

# remove just the link schemes: https://arxiv.org/abs/2401.02379, http://i.stanford.edu/~kvijay/krishnan-raj-airweb06.pdf
LS_LIST=ranking/data/preference_vectors/domain_lists/link_scheme_domains.txt

# remove link schemes + link spam discovered domains with high STR score: https://dl.acm.org/doi/10.1145/3366424.3385773
LS_STR_LIST=ranking/data/preference_vectors/domain_lists/link_scheme_str_domains_rank_sorted.txt # only take the top 1000
awk -F'\t' '{ if ($3 < 100000) { print $5 } }' ranking/output/exp-ls-str-discover.out > $LS_STR_LIST
head -n 1000 $LS_STR_LIST > $LS_STR_LIST.top1k

# combined
COMBINED_DOMAINS=ranking/data/preference_vectors/domain_lists/link_schemes_str_combined_domains.txt
cat $LS_LIST $LS_STR_LIST.top1k > $COMBINED_DOMAINS

# get node ID lists
VERTICES=./ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt
EDGES=./ranking/data/cc-main-2023-may-sep-nov-domain-edges.txt

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
}

fetch_vertex_ids $LS_LIST $VERTICES $LS_LIST.ids
fetch_vertex_ids $LS_STR_LIST.top1k $VERTICES $LS_STR_LIST.ids
fetch_vertex_ids $COMBINED_DOMAINS $VERTICES $COMBINED_DOMAINS.ids

remove_edges_with_source_id() {
    local id_list=$1
    local edge_list=$2
    local output_file=$3
    awk 'NR==FNR { 
            ids[$1] = 1
            next
        } 
        {
            if (!($1 in ids)) {
                print $0;
            }
        }' FS='\t' "$id_list" FS='\t' "$edge_list" > "$output_file"
}

remove_edges_with_source_id $LS_LIST.ids $EDGES $EDGES.ls_filtered
remove_edges_with_source_id $LS_STR_LIST.ids $EDGES $EDGES.ls_str_filtered
remove_edges_with_source_id $COMBINED_DOMAINS.ids $EDGES $EDGES.ls_combined_filtered

gzip $EDGES.ls_filtered
gzip $EDGES.ls_str_filtered
gzip $EDGES.ls_combined_filtered


# TODO: bow-tie model
# remove all backlinkers that do not have links from the center

