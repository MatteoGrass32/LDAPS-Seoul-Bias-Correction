# ==============================================================================
# TEMPERATURE BIAS CORRECTION PIPELINE (TMAX)
# Backward Selection vs. Forward Selection with Final Backtesting
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION 1: LIBRARIES
# ------------------------------------------------------------------------------
# Loading core packages for data manipulation, visualization, and regression 
# diagnostics (specifically checking for multicollinearity using VIF).
# ------------------------------------------------------------------------------
library(tidyverse)
library(ggplot2)
library(car)

# ------------------------------------------------------------------------------
# SECTION 2: DATA LOADING
# ------------------------------------------------------------------------------
# Importing the historical training and test datasets. The model learns 
# to estimate systematic prediction errors from the training set, while the 
# test set is strictly reserved for out-of-sample validation.
# ------------------------------------------------------------------------------
dati <- read.csv("CoreaForecasting2013-2017 - New_TRAINING_SET.csv")
test_df  <- read.csv("CoreaForecasting2013-2017 - New_TEST_SET.csv")

# ------------------------------------------------------------------------------
# SECTION 3: DATA CLEANING & PREPARATION
# ------------------------------------------------------------------------------
# Standardizing target variable naming across datasets. This ensures that the 
# target label matches exactly between training and testing, preventing downstream 
# errors when running the predict() function.
# ------------------------------------------------------------------------------
test_clean <- test_df

if ("Error_Tmax_Iniziale" %in% colnames(test_clean) && !"Error_Tmax" %in% colnames(test_clean)) {
  test_clean <- test_clean %>% rename(Error_Tmax = Error_Tmax_Iniziale)
}

if ("Error_Tmax_Iniziale" %in% colnames(dati) && !"Error_Tmax" %in% colnames(dati)) {
  dati <- dati %>% rename(Error_Tmax = Error_Tmax_Iniziale)
}

# ------------------------------------------------------------------------------
# SECTION 4: UTILITY FUNCTIONS
# ------------------------------------------------------------------------------
# Defining custom metrics for model evaluation. The Root Mean Squared Error (RMSE) 
# and Mean Bias functions will gauge how effectively our statistical corrections 
# improve raw meteorological model predictions.
# ------------------------------------------------------------------------------
calc_rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2, na.rm = TRUE))
}

calc_bias <- function(actual, predicted) {
  mean(predicted - actual, na.rm = TRUE)
}

# ------------------------------------------------------------------------------
# SECTION 5: FULL MODEL FORMULATION
# ------------------------------------------------------------------------------
# Constructing the baseline formula incorporating all available predictors. 
# This includes spatial metadata, atmospheric readings, temporal trends, 
# and autoregressive lag errors for both minimum and maximum temperatures.
# ------------------------------------------------------------------------------
lag_vars <- paste0(
  rep(c("ErroreTmin_Lag", "ErroreTmax_Lag"), each = 6),
  rep(1:6, times = 2)
)

formula_full <- as.formula(
  paste(
    "Error_Tmax ~ Latitude + Longitude + Elevation + Slope +",
    "RelativeHumidity_Min + RelativeHumidity_Max + Cloud_Cover_Avg +",
    "Precipitation_Avg + Wind_Speed_Avg + Latent_Heat_Flux +",
    "Solar_Radiation + TToday_Max + TToday_Min + TrendTMAX + TrendTMIN +",
    paste(lag_vars, collapse = " + ")
  )
)

# ------------------------------------------------------------------------------
# SECTION 6: BACKWARD SELECTION & DIAGNOSTICS
# ------------------------------------------------------------------------------
# Fitting the saturated model and applying automated backward elimination based 
# on Akaike Information Criterion (AIC). Standard linear model diagnostic plots 
# and Variance Inflation Factor (VIF) scores are generated to detect structural issues.
# ------------------------------------------------------------------------------
cat("\n===== SECTION A: BACKWARD SELECTION =====\n")

mod_full <- lm(formula_full, data = dati)
mod_back <- step(mod_full, direction = "backward", trace = 0)

cat("\n--- Backward Model Summary ---\n")
print(summary(mod_back))

cat("\n--- Backward Model VIF ---\n")
print(vif(mod_back))

par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))
plot(mod_back, which = 1:4)
par(mfrow = c(1, 1))

# ------------------------------------------------------------------------------
# SECTION 7: BACKWARD SELECTION BACKTEST
# ------------------------------------------------------------------------------
# Testing the backward model out-of-sample. The predicted model bias is added 
# back to the baseline numerical weather prediction (LDAPS) to compute the 
# corrected temperature and measure percentage improvements in RMSE.
# ------------------------------------------------------------------------------
pred_back <- predict(mod_back, newdata = test_clean)
tmax_back  <- test_clean$LDAPS_Tmax_lapse + pred_back

rmse_ldaps <- calc_rmse(test_clean$Next_Tmax, test_clean$LDAPS_Tmax_lapse)
rmse_back  <- calc_rmse(test_clean$Next_Tmax, tmax_back)
migl_back  <- 100 * (rmse_ldaps - rmse_back) / rmse_ldaps

cat("\n--- Backward Model Backtest ---\n")
cat(sprintf("RMSE LDAPS baseline : %.4f °C\n", rmse_ldaps))
cat(sprintf("RMSE Backward       : %.4f °C\n", rmse_back))
cat(sprintf("Improvement         : %.2f%%\n", migl_back))

# ------------------------------------------------------------------------------
# SECTION 8: FORWARD SELECTION (ADJUSTED R²)
# ------------------------------------------------------------------------------
# Implementing a manual, greedy forward selection procedure. Instead of raw 
# training RMSE—which inherently overfits as complexity increases—the algorithm 
# uses Adjusted R² to penalize redundant parameters, stopping when marginal gains halt.
# ------------------------------------------------------------------------------
cat("\n===== SECTION B: FORWARD SELECTION (ADJUSTED R²) =====\n")

variabili_disponibili <- c(
  "Latitude", "Longitude", "Elevation", "Slope",
  "RelativeHumidity_Min", "RelativeHumidity_Max", "Cloud_Cover_Avg",
  "Precipitation_Avg", "Wind_Speed_Avg", "Latent_Heat_Flux",
  "Solar_Radiation", "TToday_Max", "TToday_Min", "TrendTMAX", "TrendTMIN",
  paste0("ErroreTmax_Lag", 1:6)
)

variabili_selezionate <- c()
r2adj_history         <- c()

for (i in seq_along(variabili_disponibili)) {
  best_r2adj <- -Inf
  next_var   <- NULL
  
  for (v in setdiff(variabili_disponibili, variabili_selezionate)) {
    form <- as.formula(paste(
      "Error_Tmax ~",
      paste(c(variabili_selezionate, v), collapse = " + ")
    ))
    
    fit     <- lm(form, data = dati)
    r2adj_v <- summary(fit)$adj.r.squared
    
    if (r2adj_v > best_r2adj) {
      best_r2adj <- r2adj_v
      next_var   <- v
    }
  }
  
  if (!is.null(next_var) && (length(r2adj_history) == 0 || best_r2adj > tail(r2adj_history, 1))) {
    variabili_selezionate <- c(variabili_selezionate, next_var)
    r2adj_history         <- c(r2adj_history, best_r2adj)
    
    cat(sprintf("Step %2d | +%-25s | Adj.R²: %.4f%%\n", i, next_var, best_r2adj * 100))
  } else {
    cat(sprintf("Stop at step %d: Additional features do not improve Adj.R².\n", i))
    break
  }
}

# ------------------------------------------------------------------------------
# SECTION 9: ELBOW OPTIMIZATION PLOT
# ------------------------------------------------------------------------------
# Generating a diagnostic line plot mapping model complexity against Adjusted R². 
# A custom threshold can be set to locate the "elbow point", optimizing the balance 
# between model performance and parsimony (fixed here to 5 variables).
# ------------------------------------------------------------------------------
n_passi <- length(r2adj_history)

df_gomito <- data.frame(
  Passo      = 1:n_passi,
  R2Adj_Perc = r2adj_history * 100,
  Variabile  = variabili_selezionate
)

soglia   <- 2.5
n_ottimo <- 5
if (is.na(n_ottimo)) n_ottimo <- n_passi

cat(sprintf("\nAutomated Elbow Match: Model %d (%s)\n", n_ottimo, variabili_selezionate[n_ottimo]))

grafico_gomito <- ggplot(df_gomito, aes(x = Passo, y = R2Adj_Perc)) +
  geom_line(color = "#0072B2", linewidth = 1) +
  geom_point(size = 3, color = "#0072B2") +
  geom_vline(xintercept = n_ottimo, linetype = "dashed", color = "#D55E00", linewidth = 1) +
  geom_point(data = df_gomito[n_ottimo, ], aes(x = Passo, y = R2Adj_Perc), color = "#D55E00", size = 5) +
  annotate("text", x = n_ottimo + 0.4, y = df_gomito$R2Adj_Perc[n_ottimo], label = paste0("Model ", n_ottimo), color = "#D55E00", size = 4, hjust = 0) +
  scale_x_continuous(breaks = 1:n_passi, labels = 1:n_passi) +
  labs(
    title = "Elbow Criterion — Forward Selection (Adjusted R²)",
    subtitle = sprintf("Elbow set at Model %d: Marginal Gain < %.1f%%", n_ottimo, soglia),
    x = "Number of Model Predictors",
    y = "Adjusted R² (%)"
  ) +
  theme_minimal(base_size = 13)

print(grafico_gomito)

# ------------------------------------------------------------------------------
# SECTION 10: OPTIMAL FORWARD MODEL & DIAGNOSTICS
# ------------------------------------------------------------------------------
# Training the final optimized forward model using only the top features chosen 
# up to the elbow point. Multicollinerity metrics and diagnostic plots are evaluated.
# ------------------------------------------------------------------------------
form_ottima <- as.formula(paste(
  "Error_Tmax ~",
  paste(variabili_selezionate[1:n_ottimo], collapse = " + ")
))

mod_fwd <- lm(form_ottima, data = dati)

cat("\n--- Optimal Forward Model Summary ---\n")
print(summary(mod_fwd))

cat("\n--- Optimal Forward Model VIF ---\n")
print(vif(mod_fwd))

par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))
plot(mod_fwd, which = 1:4)
par(mfrow = c(1, 1))

# ------------------------------------------------------------------------------
# SECTION 11: OPTIMAL FORWARD MODEL BACKTEST
# ------------------------------------------------------------------------------
# Simulating the deployment of the optimal forward model onto the testing subset, 
# extracting the final predictive accuracy benchmark against the raw baseline.
# ------------------------------------------------------------------------------
pred_fwd <- predict(mod_fwd, newdata = test_clean)
tmax_fwd <- test_clean$LDAPS_Tmax_lapse + pred_fwd

rmse_fwd <- calc_rmse(test_clean$Next_Tmax, tmax_fwd)
migl_fwd <- 100 * (rmse_ldaps - rmse_fwd) / rmse_ldaps

cat("\n--- Optimal Forward Model Backtest ---\n")
cat(sprintf("RMSE LDAPS baseline : %.4f °C\n", rmse_ldaps))
cat(sprintf("RMSE Forward        : %.4f °C\n", rmse_fwd))
cat(sprintf("Improvement         : %.2f%%\n", migl_fwd))

# ------------------------------------------------------------------------------
# SECTION 12: RESIDUAL SCATTER ANALYSIS
# ------------------------------------------------------------------------------
# Visualizing residual changes at individual observation scales. Predictions 
# plotted underneath the identity diagonal line signify instances where our statistical 
# post-processing successfully diminished original system projection errors.
# ------------------------------------------------------------------------------
backtest_fwd_df <- test_clean %>%
  mutate(
    TmaxCorretta      = LDAPS_Tmax_lapse + pred_fwd,
    ErroreCorretto    = Next_Tmax - TmaxCorretta,
    AbsErroreLDAPS    = abs(Next_Tmax - LDAPS_Tmax_lapse),
    AbsErroreCorretto = abs(ErroreCorretto)
  )

grafico_scatter_fwd <- ggplot(backtest_fwd_df, aes(x = AbsErroreLDAPS, y = AbsErroreCorretto)) +
  geom_point(alpha = 0.4, color = "#0072B2") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "#D55E00", linewidth = 1) +
  labs(
    title = sprintf("Absolute Error: LDAPS vs. Forward Model (%d vars)", n_ottimo),
    subtitle = "Points under the diagonal line represent improved forecasts",
    x = "Raw LDAPS Absolute Error (°C)",
    y = sprintf("Forward Model Absolute Error (°C)", n_ottimo)
  ) +
  theme_minimal()

print(grafico_scatter_fwd)

# ------------------------------------------------------------------------------
# SECTION 13: STEP-BY-STEP FORWARD BACKTESTING
# ------------------------------------------------------------------------------
# Evaluating every incremental phase of the forward iteration on the out-of-sample 
# data. This confirms whether our training-based elbow cutoff holds up effectively 
# against truly unseen data.
# ------------------------------------------------------------------------------
cat("\n--- Out-of-Sample Progress Across All Forward Steps ---\n")



risultati_fwd <- data.frame(
  Passo              = 1:n_passi,
  Variabile_Aggiunta = variabili_selezionate,
  RMSE_Corretto      = numeric(n_passi),
  Miglioramento_Perc = numeric(n_passi)
)

for (i in 1:n_passi) {
  form_i <- as.formula(paste(
    "Error_Tmax ~",
    paste(variabili_selezionate[1:i], collapse = " + ")
  ))
  
  mod_i  <- lm(form_i, data = dati)
  pred_i <- predict(mod_i, newdata = test_clean)
  tmax_i <- test_clean$LDAPS_Tmax_lapse + pred_i
  rmse_i <- calc_rmse(test_clean$Next_Tmax, tmax_i)
  
  risultati_fwd$RMSE_Corretto[i]      <- rmse_i
  risultati_fwd$Miglioramento_Perc[i] <- 100 * (rmse_ldaps - rmse_i) / rmse_ldaps
}

grafico_backtest_fwd <- ggplot(
  risultati_fwd,
  aes(x = factor(Passo), y = Miglioramento_Perc)
) +
  geom_col(
    fill = ifelse(risultati_fwd$Passo == n_ottimo, "#D55E00", "#0072B2")
  ) +
  geom_text(
    aes(label = sprintf("%.1f%%", Miglioramento_Perc)),
    vjust = -0.5,
    size = 3.5
  ) +
  labs(
    title = sprintf("Backtest: RMSE Improvement Across All %d Forward Models", n_passi),
    subtitle = sprintf("Highlighted in orange: Model %d (Adjusted R² Elbow)", n_ottimo),
    x = "Number of Variables Included",
    y = "RMSE Improvement (%) vs. LDAPS Baseline"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(grafico_backtest_fwd)

# ------------------------------------------------------------------------------
# SECTION 14: GLOBAL PERFORMANCE COMPARISON
# ------------------------------------------------------------------------------
# Compiling and plotting a consolidated bar chart comparing raw LDAPS, 
# Backward Selection, and the Optimal Forward Selection models on final RMSE metrics.
# ------------------------------------------------------------------------------
cat("\n===== FINAL COMPARISON =====\n")

df_confronto <- data.frame(
  Modello = c("LDAPS Baseline", "Backward Selection", sprintf("Forward Sel. (%d var)", n_ottimo)),
  RMSE = c(rmse_ldaps, rmse_back, rmse_fwd)
)

print(df_confronto)

cat(sprintf("\nBackward Selection reduces RMSE by : %.2f%%\n", 100 * (rmse_ldaps - rmse_back) / rmse_ldaps))
cat(sprintf("Forward Selection reduces RMSE by  : %.2f%%\n", 100 * (rmse_ldaps - rmse_fwd) / rmse_ldaps))

nome_forward <- sprintf("Forward Sel. (%d var)", n_ottimo)
valori_colori <- c("LDAPS Baseline" = "#999999", "Backward Selection" = "#56B4E9")
valori_colori[nome_forward] <- "#D55E00"

grafico_confronto <- ggplot(df_confronto, aes(x = reorder(Modello, RMSE), y = RMSE, fill = Modello)) +
  geom_col(width = 0.6, color = "black", show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.4f °C", RMSE)), vjust = -0.5, fontface = "bold", size = 4.5) +
  scale_fill_manual(values = valori_colori) +
  labs(
    title = "Performance Comparison — Test Set RMSE",
    subtitle = "Out-of-sample assessment of Tmax bias correction strategies",
    x = NULL,
    y = "RMSE (°C)"
  ) +
  theme_minimal(base_size = 14)

print(grafico_confronto)

# ------------------------------------------------------------------------------
# SECTION 15: BIAS METRIC SUMMARY
# ------------------------------------------------------------------------------
# Computing systematic mean directional errors (Bias) across configurations. 
# A final summary data frame and corresponding plot demonstrate how effectively 
# both strategies mitigate systematic over/underestimation tendencies.
# ------------------------------------------------------------------------------
bias_ldaps <- calc_bias(test_clean$Next_Tmax, test_clean$LDAPS_Tmax_lapse)
bias_back  <- calc_bias(test_clean$Next_Tmax, tmax_back)
bias_fwd   <- calc_bias(test_clean$Next_Tmax, tmax_fwd)

migl_bias_back <- 100 * (abs(bias_ldaps) - abs(bias_back)) / abs(bias_ldaps)
migl_bias_fwd  <- 100 * (abs(bias_ldaps) - abs(bias_fwd))  / abs(bias_ldaps)

cat("\n===== BIAS AND PERCENTAGE IMPROVEMENT =====\n")
cat(sprintf("Bias LDAPS Baseline  : %+.4f °C\n", bias_ldaps))
cat(sprintf("Bias Backward        : %+.4f °C  (Improvement: %.2f%%)\n", bias_back, migl_bias_back))
cat(sprintf("Bias Forward (%d var) : %+.4f °C  (Improvement: %.2f%%)\n", n_ottimo, bias_fwd, migl_bias_fwd))

df_riepilogo <- data.frame(
  Modello              = c("LDAPS Baseline", "Backward Selection", sprintf("Forward Sel. (%d var)", n_ottimo)),
  RMSE                 = c(rmse_ldaps, rmse_back, rmse_fwd),
  Miglioramento_RMSE   = c(0, migl_back, migl_fwd),
  Bias                 = c(bias_ldaps, bias_back, bias_fwd),
  Miglioramento_Bias   = c(0, migl_bias_back, migl_bias_fwd)
)

cat("\n--- Final Summary Table ---\n")
print(df_riepilogo, digits = 4)

colori_bias <- c("LDAPS Baseline" = "#999999", "Backward Selection" = "#56B4E9")
colori_bias[sprintf("Forward Sel. (%d var)", n_ottimo)] <- "#D55E00"

grafico_bias <- ggplot(df_riepilogo, aes(x = reorder(Modello, abs(Bias)), y = Bias, fill = Modello)) +
  geom_col(width = 0.6, color = "black", show.legend = FALSE) +
  geom_hline(yintercept = 0, linetype = "solid", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%+.4f °C", Bias)), vjust = ifelse(df_riepilogo$Bias >= 0, -0.5, 1.3), fontface = "bold", size = 4.5) +
  scale_fill_manual(values = colori_bias) +
  labs(
    title    = "Bias Comparison — Test Set",
    subtitle = "Bias = mean(Predicted − Actual): positive = overestimation, negative = underestimation",
    x        = NULL,
    y        = "Bias (°C)"
  ) +
  theme_minimal(base_size = 14)

print(grafico_bias)

cat("\nVariables retained in the optimal forward model:\n")
print(variabili_selezionate[1:n_ottimo])

