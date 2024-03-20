#!/bin/bash
set -x

cd "$(dirname "$(dirname "$(realpath "$0")")")"

reverse_urls() {
    local url_list=$1
    tail -n +2 $url_list  > temp.txt 
    awk '{
        url = $1;
        sub(/\/.*/, "", url);
        split(url, parts, ".");
        reverse_url = "";
        if (length(parts) > 1) {
            for (i = length(parts); i > 1; i--) {
                if (reverse_url != "") {
                    reverse_url = reverse_url ".";
                }
                reverse_url = reverse_url parts[i];
            }
            reverse_url = reverse_url "." parts[1];
            print reverse_url;
        } else {
            print $1;
        }
    }' FS=, temp.txt > $url_list
    sort $url_list -o $url_list
    rm temp.txt
}


LABELS=../data/attributes.csv
REL_LIST=./ranking/data/preference_vectors/domain_lists/rel_domains.txt
awk '$2 >= 5 { print $1 }' FS=,  $LABELS > $REL_LIST
reverse_urls $REL_LIST

UNREL_LIST=./ranking/data/preference_vectors/domain_lists/unrel_domains.txt
awk '$2 < 5 { print $1 }' FS=,  $LABELS > $UNREL_LIST
reverse_urls $UNREL_LIST


# Link Schemes

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

find_link_schemes() {
    local id_list=$1
    local edge_list=$2
    local output_file=$3

    # Count occurrences of source IDs linking to domains in the vertex ID list
    awk -F'\t' 'NR==FNR { 
            ids[$1] = 1
            next
        } 
        {
            if ($2 in ids) {
                source_count[$1]++
            }
        } 
        END {
            for (source_id in source_count) {
                if (source_count[source_id] >= 20) {
                    print source_id, source_count[source_id]
                }
            }
        }' "$id_list" "$edge_list" > "$output_file"
}

fetch_vertex_name() {
    local id_link_count=$1
    local id_list=$2
    local output_file=$3
    awk 'NR==FNR { 
            ids[$1] = $2
            next 
        } 
        {
            if ($1 in ids) {
                print $2, ids[$1];
            }
        }' FS=' ' "$id_link_count" FS='\t' "$id_list" > "$output_file"
    sort -n "$output_file" -o "$output_file"
}

filter_labelled_domains() {
    local labels=$1
    local domain_link_count=$2
    awk 'NR==FNR { 
            labels[$1] = 1
            next 
        } 
        {
            if (!($1 in labels)) {
                print $0
            }
        }' FS='\t' "$labels" FS=' ' "$domain_link_count"  > "$domain_link_count"
}

EDGES=./ranking/data/cc-main-2023-may-sep-nov-domain-edges.txt
VERTICES=./ranking/data/cc-main-2023-may-sep-nov-domain-vertices.txt
fetch_vertex_ids $UNREL_LIST $VERTICES $UNREL_LIST.ids


LS_LIST=./ranking/data/preference_vectors/domain_lists/cc_link_scheme_domains.txt
find_link_schemes $UNREL_LIST.ids $EDGES $LS_LIST
fetch_vertex_name $LS_LIST $VERTICES $LS_LIST.domains
filter_labelled_domains $UNREL_LIST $LS_LIST.domains 
filter_labelled_domains $REL_LIST $LS_LIST.domains


awk '$2 > threshold { print $1 }' threshold=150 $LS_LIST.domains > $LS_LIST.domains.final
# sort -n $LS_LIST -o $LS_LIST

# conda activate lsr
# cd ../interventions/
# python3 link_schemes.py > $LS_LIST
# reverse_urls $LS_LIST
