# cc-webgraph

## Setup
First, download the vertice and edge lists. For more up-to-date webgraphs see https://commoncrawl.org/web-graphs.
```
mkdir ranking/data
cd ranking/data
wget https://data.commoncrawl.org/projects/hyperlinkgraph/cc-main-2023-may-sep-nov/domain/cc-main-2023-may-sep-nov-domain-vertices.txt.gz
wget https://data.commoncrawl.org/projects/hyperlinkgraph/cc-main-2023-may-sep-nov/domain/cc-main-2023-may-sep-nov-domain-edges.txt.gz
cp cc-main-2023-may-sep-nov-domain-vertices.txt.gz cc-main-2023-may-sep-nov-domain-vertices.txt.gz.2
gzip -d cc-main-2023-may-sep-nov-domain-vertices.txt.gz.2
cp cc-main-2023-may-sep-nov-domain-edges.txt.gz cc-main-2023-may-sep-nov-domain-edges.txt.gz.2
gzip -d cc-main-2023-may-sep-nov-domain-edges.txt.gz.2
```

Now, compile the webgraph tools and run scripts once to generate the required BVGraph objects:
```
cd ../../
mkdir output
mvn package
./src/script/webgraph_ranking/process_webgraph.sh preference_up ./ranking/data/cc-main-2023-may-sep-nov-domain-vertices-copy.txt.gz ./ranking/data/cc-main-2023-may-sep-nov-domain-edges-copy.txt.gz ./ranking/output/
```

Run PPR experiments:
```
./ranking/prepare_ppr_domain_list.sh
./ranking/run_link_spam_detection.sh
./ranking/run_all_exps.sh
```

Run Multi-Category Link Scheme experiment:
```
cd ranking/casinos
./run_multi_category_ppr_exp.sh
```

Run Edge removal experiments:
```
./ranking/run_edge_removal.sh
```

Generate pre-post intervention plot and multi-category link scheme hexplot:
```
cd ranking
Rscript intervention_graphs.R
```

## Credits
Thanks to the authors of the [WebGraph framework](https://webgraph.di.unimi.it/) used to process the graphs and compute page rank and harmonic centrality. See also Sebastiano Vigna's projects [webgraph](//github.com/vigna/webgraph) and [webgraph-big](//github.com/vigna/webgraph-big).
