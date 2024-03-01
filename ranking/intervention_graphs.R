library(tidyverse)


setwd('~/Projects/link_scheme_removal')

cc_rank_cols = c("harmonic_rank", "harmonic_centrality", "pagerank_rank", "pagerank_centrality", "url", "a")


## Intervention Results
expbline <- read.csv('./stats/intervention_results/news_only_effects/exp-baseline.label_only.out', sep = '\t', col.names = cc_rank_cols, header = FALSE)
expbline <- as_tibble(expbline)
expbline$Intervention <- 'Pre-Intervention Baseline'
exppprrank <- read.csv('./stats/intervention_results/news_only_effects/exp-rel-ppr-ranks.label_only.txt', col.names = cc_rank_cols, sep = '\t', header = FALSE)
exppprrank <- as_tibble(exppprrank)
exppprrank$Intervention <- 'PPR on Reliable News'
explsppr <- read.csv('./stats/intervention_results/news_only_effects/exp-ls-ppr-down.label_only.out',col.names = cc_rank_cols, sep = '\t', header = FALSE)
explsppr <- as_tibble(explsppr) 
explsppr$Intervention <- 'Inv-PPR on Link Schemes'
expstrppr <- read.csv('./stats/intervention_results/news_only_effects/exp-ls-str-ppr-down.label_only.out',col.names = cc_rank_cols, sep = '\t', header = FALSE)
expstrppr <- as_tibble(expstrppr)
expstrppr$Intervention <- 'Inv-PPR on Anti-TrustRank Spam'
exppunrelprrank <- read.csv('./stats/intervention_results/news_only_effects/exp-unrel-ppr-down.label_only.out',col.names = cc_rank_cols, sep = '\t', header = FALSE)
exppunrelprrank <- as_tibble(exppunrelprrank)
exppunrelprrank$Intervention <- 'Inv-PPR on Unreliable News'
lsfr <-  read.csv('./stats/intervention_results/news_only_effects/ls_filtered-ranks.label_only.txt',col.names = cc_rank_cols, sep = '\t', header = FALSE)
lsfr <- as_tibble(lsfr)
lsfr$Intervention <- 'Edge Removal on Link Schemes'
lsafr <- read.csv('./stats/intervention_results/news_only_effects/ls_atr_filtered-ranks.label_only.txt.txt',col.names = cc_rank_cols, sep = '\t', header = FALSE)
lsafr <- as_tibble(lsafr)
lsafr$Intervention <- 'Edge Removal on Anti-TrustRank Spam'

modify_websites <- function(urls) {
  modified_urls <- sapply(strsplit(urls, "\\."), function(x) {
    paste(rev(x), collapse = ".")
  })
  return(modified_urls)
}

labels <- read_csv('./stats/attributes_3k.csv') %>% select(domain = url, label)

df <- bind_rows(expbline,exppprrank,explsppr,expstrppr,exppunrelprrank,lsfr,lsafr)
df$domain <- modify_websites(df$url)
df <- df %>% left_join(labels) %>% drop_na()

df <- df %>% select(pagerank_centrality, domain, label, Intervention)
df$log_pagerank_centrality <- log(df$pagerank_centrality)
df <- df[!is.infinite(df$log_pagerank_centrality) | df$log_pagerank_centrality != -Inf, ]
order_of_labs = c("PPR on Reliable News","Pre-Intervention Baseline","Inv-PPR on Link Schemes",
                  "Inv-PPR on Anti-TrustRank Spam","Inv-PPR on Unreliable News",
                  "Edge Removal on Link Schemes", "Edge Removal on Anti-TrustRank Spam")

df$Intervention <- factor(df$Intervention, levels = order_of_labs)
df$label <- as.factor(df$label)
palette = c("mistyrose","tomato3",'bisque2', 'lightpink1', 'lightgoldenrod', 'cadetblue1',  'azure2')

ggplot(df, aes(x = label, y = log_pagerank_centrality, fill = Intervention)) +
  scale_color_manual(values = palette) +
  stat_boxplot(geom = "errorbar")+
  geom_boxplot(alpha = 1, outlier.color = NA, fatten = 0.8) +
  #geom_point(position = , alpha = 0.2) +
  #facet_wrap(~ label, scales = "free") +
  scale_fill_manual(values = palette)+
  labs(x = "", y = "Log Pagerank Centrality") +
  #scale_y_continuous(trans='log10')+
  #stat_boxplot(aes(label, log_pagerank_centrality, fill = Intervention), 
  #              geom='errorbar', linetype=1, width=0.5) + 
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
        panel.background = element_blank(), axis.line=element_line(color='black'))+
  theme(text = element_text(size = 25),
        axis.title.y = element_text(size=30),
        axis.title.x = element_text(size=30)) + 
  scale_alpha_manual(values=c(1,0.1)) +
  theme(
    legend.position = c(.95, 0.01),
    legend.justification = c("right", "bottom"),
    legend.box.just = "right",
    legend.margin = margin(5, 5, 5, 5)
  )+
  scale_x_discrete(labels=c("1" = "V. Unreliable", "3" = 'Unreliable', "4" = "Mixed",
                            "5" = "Reliable", "6" = 'V. Reliable'))
ggsave('interventions_boxplots_2.png', dpi = 300, height = 11, width = 20, units = 'in')

#theme(legend.position = "bottom", legend.justification = "right",legend.box.just = "right")
library(tidyverse)
setwd('~/Projects/link_scheme_removal')
# big dataset
df <- read.csv("stats/intervention_results/multi_category_scatter/exp-ls-atr-discover-top.out.sorted", sep = '\t', col.names = cc_rank_cols, header = FALSE)
df2 <- read.csv("stats/intervention_results/multi_category_scatter/exp-scam-casino-discover-top.out.sorted", sep = '\t', col.names = cc_rank_cols, header = FALSE)


df$domain <-  modify_websites(df$url)
df2$domain <-  modify_websites(df2$url) # casino
df <- df %>% select(domain, opr = pagerank_centrality)
df2 <- df2 %>% select(domain, ipr = pagerank_centrality)

df <- df %>% left_join(df2)
df <- df %>% drop_na()
df$logopr = log10(df$opr)
df$logipr = log10(df$ipr)

contains_keywords <- function(column, keywords) {
  column <- tolower(column)
  
  result <- numeric(length(column))
    for (keyword in keywords) {
    matches <- grepl(keyword, column)
    result <- result + as.numeric(matches)
  }
    result <- as.integer(result > 0)
  
  return(result)
}

keywords <- c('seo','directory','rank','link','article','site')
df$keyphrase <- contains_keywords(df$domain, keywords)
df$`Link Scheme Name` <- ifelse(df$keyphrase ==1, "Yes", 'No')

#df$keyphrase <- as.factor(df$keyphrase)
df$`Link Scheme Name` <- as.factor(df$`Link Scheme Name`)

ggplot(df, aes(x=logipr, y=logopr, color = `Link Scheme Name`)) + 
  geom_hex(aes(fill="#000000",alpha=..count..),fill="#191919", size = 1)+
  #geom_smooth(aes(group=1),color='#A9A9A9')+
  #scale_fill_discrete(name = "Dose",
  scale_color_manual(values = c("#0000ff","brown4"), labels = c('No', 'Yes')) +
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
        panel.background = element_blank(), axis.line=element_line(color='black'))+
  theme(text = element_text(size = 25),
        axis.title.y = element_text(size=25),
        axis.title.x = element_text(size=25)) +
  xlab('Log News Anti-TrustRank')+
  ylab('Log Casino Anti-TrustRank')+ 
  labs(color='Majority Link Scheme')+
  theme(
    legend.position = c(0.05, 0.95),
    legend.justification = c("left", "top"),
    legend.box.just = "left",
    legend.margin = margin(5, 5, 5, 5)
  )# Change legend values
ggsave('link_scheme_counts.png', dpi = 300, height = 11, width = 11, units = 'in')



### plot 10A
library(tidyverse)


setwd('~/Projects/link_scheme_removal')

cc_rank_cols = c("harmonic_rank", "harmonic_centrality", "pagerank_rank", "pagerank_centrality", "url", "a")

## Intervention Results
expbline <- read.csv('./stats/intervention_results/news_only_effects/exp-baseline.label_only.out', sep = '\t', col.names = cc_rank_cols, header = FALSE)
expbline <- as_tibble(expbline)
expbline$Intervention <- 'Pre-Intervention Baseline'

eratmd <- read.csv("stats/intervention_results/news_only_effects/ls_multi_domain_atr-ranks.label_only.txt", sep = '\t', col.names = cc_rank_cols, header = FALSE)
eratmd <- as_tibble(eratmd)
eratmd$Intervention <- 'Edge Removal on Multi-Domain ATR'

eratnd <- read.csv("stats/intervention_results/news_only_effects/ls_combined_filtered-ranks.label_only.txt", sep = '\t', col.names = cc_rank_cols, header = FALSE)
eratnd <- as_tibble(eratnd)
eratnd$Intervention <- 'Edge Removal on News-Domain ATR'

df <- bind_rows(expbline, eratmd, eratnd)
df$domain <- modify_websites(df$url)
df <- df %>% left_join(labels) %>% select(pagerank_centrality, domain, label, Intervention) %>% drop_na()

#df <- df %>% select(pagerank_centrality, domain, label, Intervention)
df$log_pagerank_centrality <- log10(df$pagerank_centrality)
df <- df[!is.infinite(df$log_pagerank_centrality) | df$log_pagerank_centrality != -Inf, ]
order_of_labs = c("Pre-Intervention Baseline",'Edge Removal on Multi-Domain ATR','Edge Removal on News-Domain ATR')

df$Intervention <- factor(df$Intervention, levels = order_of_labs)
df$label <- as.factor(df$label)
palette = c("mistyrose","tomato3", 'cadetblue1')


ggplot(df, aes(x = label, y = log_pagerank_centrality, fill = Intervention)) +
  scale_color_manual(values = palette) +
  stat_boxplot(geom = "errorbar")+
  geom_boxplot(alpha = 1, outlier.color = NA, fatten = 0.8) +
  #geom_point(position = , alpha = 0.2) +
  scale_fill_manual(values = palette)+
  labs(x = "", y = "Log Pagerank Centrality") +
  #scale_y_continuous(trans='log10')+
  #stat_boxplot(aes(label, log_pagerank_centrality, fill = Intervention), 
  #              geom='errorbar', linetype=1, width=0.5) + 
  theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(),
        panel.background = element_blank(), axis.line=element_line(color='black'))+
  theme(text = element_text(size = 25),
        axis.title.y = element_text(size=25),
        axis.title.x = element_text(size=25)) + 
  scale_alpha_manual(values=c(1,0.1)) +
  theme(
    legend.position = c(0.05, 0.95),
    legend.justification = c("left", "top"),
    legend.box.just = "left",
    legend.margin = margin(5, 5, 5, 5),
    legend.title = element_text(size=20), #change legend title font size
    legend.text = element_text(size=20)) +
  scale_x_discrete(labels=c("1" = "V. Unreliable", "3" = 'Unreliable', "4" = "Mixed",
                            "5" = "Reliable", "6" = 'V. Reliable'))
ggsave('interventions_boxplots_md.png', dpi = 300, height = 11, width = 16, units = 'in')

