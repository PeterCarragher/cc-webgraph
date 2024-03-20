import pandas as pd
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

# Custom aggregation function to select the string with the minimum length, prioritizing ".com"
def min_length_string(series):
    # Calculate lengths of strings
    lengths = series.apply(len)
    
    # Find the index of the string with the minimum length
    min_length_index = lengths.idxmin()
    
    # Check if there are multiple strings with the minimum length
    min_lengths = lengths[lengths == lengths.min()]
    
    # If there are multiple strings with the minimum length
    if len(min_lengths) > 1:
        # Check if ".com" is in any of the strings
        com_indices = series[series.str.startswith('com.')].index
        
        # If there is at least one string containing ".com"
        if len(com_indices) > 0:
            # Find the shortest length among indices containing ".com"
            shortest_com_index = min(com_indices, key=lambda x: lengths[x])
            return series[shortest_com_index]
    
    return series[min_length_index]


df_casino = pd.read_csv('bad_casino_urls.csv', names=['url','name'])
df_casino = df_casino.groupby('name')['url'].agg(min_domain=min_length_string)
df_casino.reset_index()['min_domain'].to_csv('cc_spam_casino_urls.csv', index=False)
# df_casino.reset_index()['min_domain'].apply(reverse_url).to_csv('bad_casino_urls_filtered_reversed.csv', index=False)
