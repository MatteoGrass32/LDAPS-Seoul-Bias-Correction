# ==============================================================================
# PRELIMINARY INFERENTIAL TESTS
#
# Objective:
# To verify whether the LDAPS prediction bias is a systematic structural flaw,
# if its direction matches our physical expectations, and if it is statistically 
# significant before we proceed with machine learning corrections.
#
# Error Convention: e = Observed - Predicted
#   e > 0  --> LDAPS underestimates the true temperature
#   e < 0  --> LDAPS overestimates the true temperature
# ==============================================================================

library(tidyverse)
library(car)

# We use the preliminary dataset specifically generated for EDA (Exploratory Data Analysis)
df <- read.csv("DataSetWithErrors.csv")

# ==============================================================================
# GLOBAL MEAN BIAS TEST (TWO-SIDED)
#
# First Level: We test if the mean error is statistically different from zero.
# If the model were perfect, the errors would be random white noise around zero.
#
# H0: E[Error_Tmax] = 0 (No Bias)
# H1: E[Error_Tmax] != 0 (Presence of Bias)
#
# H0: E[Error_Tmin] = 0 (No Bias)
# H1: E[Error_Tmin] != 0 (Presence of Bias)
#
# We utilize both the parametric Student's t-test and the non-parametric 
# Wilcoxon signed-rank test to ensure robustness against non-normality.
# ==============================================================================

t_Tmax_two <- t.test(df$Error_Tmax,
                     mu = 0,
                     alternative = "two.sided",
                     conf.level = 0.95)

t_Tmin_two <- t.test(df$Error_Tmin,
                     mu = 0,
                     alternative = "two.sided",
                     conf.level = 0.95)

w_Tmax_two <- wilcox.test(df$Error_Tmax,
                          mu = 0,
                          alternative = "two.sided",
                          conf.int = TRUE)

w_Tmin_two <- wilcox.test(df$Error_Tmin,
                          mu = 0,
                          alternative = "two.sided",
                          conf.int = TRUE)

tab_8.1_general <- data.frame(
  Variable   = c("Error_Tmax", "Error_Tmin"),
  Mean       = round(c(mean(df$Error_Tmax, na.rm=TRUE), mean(df$Error_Tmin, na.rm=TRUE)), 4),
  SD         = round(c(sd(df$Error_Tmax, na.rm=TRUE),   sd(df$Error_Tmin, na.rm=TRUE)),   4),
  t_stat     = round(c(t_Tmax_two$statistic, t_Tmin_two$statistic), 3),
  p_ttest    = c(t_Tmax_two$p.value, t_Tmin_two$p.value),
  p_wilcoxon = c(w_Tmax_two$p.value, w_Tmin_two$p.value),
  CI_lower   = round(c(t_Tmax_two$conf.int[1], t_Tmin_two$conf.int[1]), 4),
  CI_upper   = round(c(t_Tmax_two$conf.int[2], t_Tmin_two$conf.int[2]), 4)
)

cat("=== 8.1 General Test on Global Mean Bias ===
")
print(tab_8.1_general)

cat("
Conclusion 8.1:
")
cat(sprintf("  Tmax: %s
",
            ifelse(t_Tmax_two$p.value < 0.05,
                   "H0 Rejected: The mean bias is strictly different from zero.",
                   "H0 Not Rejected: No evidence of mean bias.")))
cat(sprintf("  Tmin: %s

",
            ifelse(t_Tmin_two$p.value < 0.05,
                   "H0 Rejected: The mean bias is strictly different from zero.",
                   "H0 Not Rejected: No evidence of mean bias.")))


# ==============================================================================
# DIRECTIONAL BIAS TEST (ONE-SIDED)
#
# Second Level: We verify the specific physical direction of the bias.
# Does LDAPS systematically underestimate the heat (Tmax) and overestimate 
# the cooling (Tmin)?
#
# Tmax:
# H0: E[Error_Tmax] <= 0
# H1: E[Error_Tmax] > 0  (Systematic Underestimation)
#
# Tmin:
# H0: E[Error_Tmin] >= 0
# H1: E[Error_Tmin] < 0  (Systematic Overestimation)
#
# This test answers the core research question: is the global model structurally 
# failing to capture the urban heat basin extremes?
# ==============================================================================

t_Tmax_dir <- t.test(df$Error_Tmax,
                     mu = 0,
                     alternative = "greater",
                     conf.level = 0.95)

t_Tmin_dir <- t.test(df$Error_Tmin,
                     mu = 0,
                     alternative = "less",
                     conf.level = 0.95)

w_Tmax_dir <- wilcox.test(df$Error_Tmax,
                          mu = 0,
                          alternative = "greater",
                          conf.int = TRUE)

w_Tmin_dir <- wilcox.test(df$Error_Tmin,
                          mu = 0,
                          alternative = "less",
                          conf.int = TRUE)

tab_8.1_directional <- data.frame(
  Variable          = c("Error_Tmax", "Error_Tmin"),
  Expected_Direction= c("Greater than 0", "Less than 0"),
  Mean              = round(c(mean(df$Error_Tmax, na.rm=TRUE), mean(df$Error_Tmin, na.rm=TRUE)), 4),
  t_stat            = round(c(t_Tmax_dir$statistic, t_Tmin_dir$statistic), 3),
  p_ttest           = c(t_Tmax_dir$p.value, t_Tmin_dir$p.value),
  p_wilcoxon        = c(w_Tmax_dir$p.value, w_Tmin_dir$p.value)
)

cat("=== 8.1b Directional Bias Test ===
")
print(tab_8.1_directional)

cat("
Conclusion 8.1b:
")
cat(sprintf("  Tmax: %s
",
            ifelse(t_Tmax_dir$p.value < 0.05,
                   "Evidence of systematic UNDERESTIMATION of daytime heat.",
                   "No sufficient evidence of systematic underestimation.")))
cat(sprintf("  Tmin: %s

",
            ifelse(t_Tmin_dir$p.value < 0.05,
                   "Evidence of systematic OVERESTIMATION of nighttime cooling.",
                   "No sufficient evidence of systematic overestimation.")))
