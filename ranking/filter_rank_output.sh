filter_giant_file() {
    local labeled_list=$1
    local giant_file=$2
    local output_file=$3
    local giant_url_col=$4

    echo "$labeled_list"
    echo "$giant_file"
    echo "$output_file"

    awk -v col="$giant_url_col" \
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
                print $0;
            }
        }' FS=, "$labeled_list" FS='\t' "$giant_file" > "$output_file"
}

LABELS=$1   # labelled domains that we care about final ranks for
RANK_FILE=$2  # exp name for rank outputs
RANK_DIR=$3 # output dir

filter_giant_file $LABELS $RANK_DIR/$RANK_FILE-ranks.txt $RANK_DIR/$RANK_FILE-ranks.label_only.txt 5