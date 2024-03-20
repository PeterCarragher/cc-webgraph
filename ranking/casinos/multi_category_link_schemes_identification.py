import pandas as pd
from scipy.stats import ttest_ind
from statsmodels.formula.api import ols
from statsmodels.stats.anova import anova_lm
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.stats import mannwhitneyu, kruskal
import numpy as np

def reverse_url(url):
    components = str(url).split('.')
    reversed_url = '.'.join(components[::-1])
    return reversed_url

metric="pagerank_centrality"
casino_atr_file='/home/pcarragh/dev/link_scheme_removal/cc-webgraph/ranking/output/exp-scam-casino-discover-top.out.sorted'
news_atr_file='/home/pcarragh/dev/link_scheme_removal/cc-webgraph/ranking/output/exp-ls-atr-discover-top.out.sorted'
cc_rank_cols = ["harmonic_rank", "harmonic_centrality", "pagerank_rank", "pagerank_centrality", "url", "a"]

# Read pre and post rankings data
df_casino_atr = pd.read_csv(casino_atr_file, sep='\t', names=[col + '_casino' for col in cc_rank_cols])
df_news_atr = pd.read_csv(news_atr_file, sep='\t', names=[col + '_news' for col in cc_rank_cols])
# pre_rankings['url'] = pre_rankings['url'].apply(reverse_url)
# post_rankings['url'] = post_rankings['url'].apply(reverse_url)


# Filter columns
df_casino_atr = df_casino_atr.iloc[:, :-1]  # Drop last column
df_news_atr = df_news_atr.iloc[:, :-1]  # Drop last column

# Merge with domain labels data
df_atr_multi_domain = df_casino_atr.merge(df_news_atr, left_on='url_casino', right_on='url_news', how='inner')
df_atr_multi_domain_cut = df_atr_multi_domain[(df_atr_multi_domain['pagerank_centrality_news']>0.0002) & (df_atr_multi_domain['pagerank_centrality_casino']>0.0003)]
df_atr_multi_domain_cut['clickable_url'] = df_atr_multi_domain_cut['url_news'].apply(reverse_url)
# df_atr_multi_domain_cut.to_csv('multi-domain-link-schemes-ranks.csv', index=False)
df_atr_multi_domain_cut.to_csv('multi-domain-link-schemes-urls.csv', index=False, columns=['url_news'])


