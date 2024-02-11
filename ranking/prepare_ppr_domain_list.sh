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


LABELS=../../link_scheme_removal/data/attributes.csv
REL_LIST=../data/preference_vectors/domain_lists/rel_domains.txt
awk '$2 >= 5 { print $1 }' FS=,  $LABEL > $REL_LIST
reverse_urls $REL_LIST

UNREL_LIST=../data/preference_vectors/domain_lists/unrel_domains.txt
awk '$2 < 5 { print $1 }' FS=,  $LABEL > $UNREL_LIST
reverse_urls $UNREL_LIST

LS_LIST=../data/preference_vectors/domain_lists/link_scheme_domains.txt
conda activate lsr
python3 ../../link_scheme_removal