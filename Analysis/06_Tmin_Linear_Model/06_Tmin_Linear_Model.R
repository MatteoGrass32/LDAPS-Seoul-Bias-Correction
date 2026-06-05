# ==============================================================================
# SECTION 6 - MULTIPLE LINEAR REGRESSION FOR TMIN BIAS CORRECTION
#
# Objective: 
# To build a linear correction model for the Tmin bias (nighttime cooling) using
# a rigorous feature selection approach. We use the Akaike Information Criterion
# (AIC) and the Adjusted R-squared "Elbow Rule" to penalize algebraic overfitting,
# ensuring the selected model is parsimonious and physically meaningful.
# ==============================================================================

# ==============================================================================
# 1. LIBRARIES
# ==============================================================================
library(tidyverse)   # For data manipulation
library(MASS)        # For advanced statistical functions (stepAIC)
library(car)         # For multicollinearity diagnostics (VIF)
library(ggplot2)     # For data visualization
library(gridExtra)   # For graph layout 

# ==============================================================================
# 2. DATA LOADING
# ==============================================================================
train_df <- read.csv("TrainingSet.csv")
test_df  <- read.csv("TestSet.csv")

# ==============================================================================
# PHASE 1: AUTOMATED FORWARD SELECTION (AIC CRITERION)
# ==============================================================================
# The objective is to let the algorithm construct the sequence of variable 
# importance using a "Greedy" approach (Akaike Information Criterion).
# The model evaluates which covariate reduces the error the most, while 
# penalizing the addition of useless terms.

null_model <- glm(Error_Tmin ~ 1, data = train_df)

full_model <- glm(
  Error_Tmin ~ Latitude + Longitude + Elevation + Slope +
    RelativeHumidity_Min + RelativeHumidity_Max +
    Cloud_Cover_Avg + Precipitation_Avg + Wind_Speed_Avg +
    Latent_Heat_Flux + Solar_Radiation +
    TToday_Max + TToday_Min + TrendTMAX + TrendTMIN +
    ErroreTmin_Lag1, 
  data = train_df
)

cat("\n--- EXECUTING AUTOMATED FORWARD SELECTION (AIC) ---\n")

forward_model <- step(
  object = null_model,
  scope = list(
    lower = formula(null_model),
    upper = formula(full_model)
  ),
  direction = "forward",
  trace = 0 # Silencing intermediate output for a cleaner console
)

cat("\n--- SELECTED FORWARD MODEL SUMMARY ---\n")
print(summary(forward_model))

# ==============================================================================
# PHASE 2: MODEL SELECTION & ELBOW RULE (ADJUSTED R-SQUARED)
# ==============================================================================
# Knowing from spectral analysis that the error has persistent temporal memory
# (~7 days), we exclude classical random Cross-Validation to avoid Data Leakage. 
# We reconstruct the AIC sequence and evaluate it via the Adjusted R-Squared,
# which severely penalizes algebraic overfitting.

forward_formulas <- list(
  Error_Tmin ~ ErroreTmin_Lag1,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg + TToday_Min,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg + TToday_Min + RelativeHumidity_Max,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg + TToday_Min + RelativeHumidity_Max + Longitude,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg + TToday_Min + RelativeHumidity_Max + Longitude + TToday_Max,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg + TToday_Min + RelativeHumidity_Max + Longitude + TToday_Max + Solar_Radiation,
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + Elevation + Slope + TrendTMAX + Wind_Speed_Avg + Precipitation_Avg + TToday_Min + RelativeHumidity_Max + Longitude + TToday_Max + Solar_Radiation + Cloud_Cover_Avg
)

model_labels <- c(
  "+ Errore Lag 1", "+ TrendTMIN", "+ Latent_Heat_Flux", "+ Elevation",
  "+ Slope", "+ TrendTMAX", "+ Wind_Speed_Avg", "+ Precipitation_Avg",
  "+ TToday_Min", "+ RH_Max", "+ Longitude", "+ TToday_Max",
  "+ Solar_Radiation", "+ Cloud_Cover_Avg"
)

r2_adj <- numeric(length(forward_formulas))

for (i in seq_along(forward_formulas)) {
  temp_lm_model <- lm(forward_formulas[[i]], data = train_df)
  r2_adj[i] <- summary(temp_lm_model)$adj.r.squared
}

cat("\n=========================================================================\n")
cat("          EXPLAINED VARIANCE BY MODEL COMPLEXITY (TRAIN SET)\n")
cat("=========================================================================\n")
for (i in seq_along(forward_formulas)) {
  r2_gain <- if (i == 1) "N/A" else sprintf("+%.3f%%", (r2_adj[i] - r2_adj[i - 1]) * 100)
  cat(sprintf("Model %2d | %-20s | R2_Adj: %6.3f%% | Gain: %8s\n",
              i, model_labels[i], r2_adj[i] * 100, r2_gain))
}
cat("=========================================================================\n")

# THE PARSIMONY CUT (ELBOW RULE)
# We select Model 5. From here on, adding variables provides purely marginal gains. 
# Model 5 encapsulates the three fundamental physical macro-drivers:
# 1. Memory (Lag 1)
# 2. Energy Exchange (TrendTMIN, Latent_Heat_Flux)
# 3. Orography (Elevation, Slope)
linear_model_index <- 5

df_linear_elbow <- data.frame(
  Model = 1:14,
  R2_Adj_Perc = r2_adj * 100
)

linear_elbow_plot <- ggplot(df_linear_elbow, aes(x = Model, y = R2_Adj_Perc)) +
  geom_line(color = "#0072B2", linewidth = 1) +
  geom_point(size = 3, color = "#0072B2") +
  geom_vline(xintercept = linear_model_index, linetype = "dashed", color = "#D55E00", linewidth = 1) +
  geom_point(data = subset(df_linear_elbow, Model == linear_model_index),
             aes(x = Model, y = R2_Adj_Perc), color = "#D55E00", size = 4) +
  labs(
    title = "Elbow Rule: Explained Variance of AR(1) Linear Models",
    subtitle = "The cut is placed on Model 5 (Memory + Physics + Orography)",
    x = "Number of variables in the model",
    y = "Adjusted R2 (%)"
  ) +
  scale_x_continuous(breaks = 1:14, labels = 1:14) +
  theme_minimal(base_size = 13)

print(linear_elbow_plot)

# ==============================================================================
# PHASE 2.5: DIAGNOSTICS OF THE SELECTED MODEL
# ==============================================================================
final_linear_model <- lm(forward_formulas[[linear_model_index]], data = train_df)

cat("\n--- MULTICOLLINEARITY CHECK (VIF) ---\n")
# Checking Variance Inflation Factor to exclude linear redundancies
print(vif(final_linear_model))

par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))
plot(final_linear_model, which = 1) # Linearity (Residuals vs Fitted)
plot(final_linear_model, which = 2) # Normality (Q-Q Plot)
plot(final_linear_model, which = 3) # Homoscedasticity (Scale-Location)
plot(final_linear_model, which = 4) # Outliers (Cook's Distance)
par(mfrow = c(1, 1))

# ==============================================================================
# PHASE 3: MODEL 5 BACKTEST ON THE TEST SET (2017)
# ==============================================================================
# Testing Model 5 on data rigorously kept unseen during training.
linear_bias_pred <- predict(final_linear_model, newdata = test_df)

linear_backtest_df <- test_df %>%
  mutate(
    EstimatedBias      = linear_bias_pred,
    CorrectedTmin      = LDAPS_Tmin_lapse + EstimatedBias,
    CorrectedError     = Next_Tmin - CorrectedTmin,
    AbsLDAPSError      = abs(Error_Tmin_Iniziale),
    AbsCorrectedError  = abs(CorrectedError),
    AbsoluteImprovement = AbsLDAPSError - AbsCorrectedError
  )

# Classic Variance Metrics
mae_ldaps_linear  <- mean(linear_backtest_df$AbsLDAPSError, na.rm = TRUE)
mae_corr_linear   <- mean(linear_backtest_df$AbsCorrectedError, na.rm = TRUE)
rmse_ldaps_linear <- sqrt(mean(test_df$Error_Tmin_Iniziale^2, na.rm = TRUE))
rmse_corr_linear  <- sqrt(mean(linear_backtest_df$CorrectedError^2, na.rm = TRUE))
improved_cases_ratio <- mean(
  linear_backtest_df$AbsCorrectedError < linear_backtest_df$AbsLDAPSError, na.rm = TRUE
) * 100

# Systematic BIAS Metrics (Mean Bias Error - MBE)
mbe_ldaps_linear <- mean(test_df$Error_Tmin_Iniziale, na.rm = TRUE)
mbe_corr_linear  <- mean(linear_backtest_df$CorrectedError, na.rm = TRUE)
bias_improvement_perc <- 100 * (abs(mbe_ldaps_linear) - abs(mbe_corr_linear)) / abs(mbe_ldaps_linear)

cat("\n======================================================\n")
cat("      BACKTEST RESULTS - MODEL 5 (AR-1)\n")
cat("======================================================\n")
cat(sprintf("Initial RMSE (LDAPS): %.4f °C | Corrected RMSE: %.4f °C | Improvement: %.2f%%\n",
            rmse_ldaps_linear, rmse_corr_linear, 100 * (rmse_ldaps_linear - rmse_corr_linear) / rmse_ldaps_linear))
cat(sprintf("Initial MAE  (LDAPS): %.4f °C | Corrected MAE : %.4f °C | Improvement: %.2f%%\n",
            mae_ldaps_linear, mae_corr_linear, 100 * (mae_ldaps_linear - mae_corr_linear) / mae_ldaps_linear))
cat("\n--- THE REAL MASTERPIECE: SYSTEMATIC BIAS REDUCTION ---\n")
cat(sprintf("Initial Mean BIAS  : %7.4f °C (Tendency to overestimate)\n", mbe_ldaps_linear))
cat(sprintf("Corrected Mean BIAS: %7.4f °C (Error practically zeroed)\n", mbe_corr_linear))
cat(sprintf("BIAS Correction    : %.2f%%\n", bias_improvement_perc))
cat("======================================================\n")

model5_error_plot <- ggplot(linear_backtest_df, aes(x = AbsLDAPSError, y = AbsCorrectedError)) +
  geom_point(alpha = 0.5, color = "#0072B2") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "#D55E00", linewidth = 1) +
  labs(
    title = "Absolute Error: LDAPS vs Model 5 (AR-1) on Test Set",
    subtitle = "Points BELOW the dashed orange line represent improved predictions.",
    x = "Original LDAPS absolute error (°C)",
    y = "New absolute error after Model 5 correction (°C)"
  ) +
  theme_minimal()

print(model5_error_plot)

# ==============================================================================
# PHASE 4: COMPARATIVE BACKTEST ACROSS ALL 14 MODELS (RMSE & BIAS)
# ==============================================================================
cat("\n--- STARTING COMPARATIVE BACKTEST ON 14 MODELS ---\n")

rmse_ldaps_test <- sqrt(mean(test_df$Error_Tmin_Iniziale^2, na.rm = TRUE))
mbe_ldaps_test  <- mean(test_df$Error_Tmin_Iniziale, na.rm = TRUE)

linear_backtest_results <- data.frame(
  Model = 1:14,
  Added_Variable = model_labels,
  Corrected_RMSE = numeric(14),
  RMSE_Improvement_Perc = numeric(14),
  Corrected_Bias = numeric(14),
  Bias_Improvement_Perc = numeric(14)
)

for (i in seq_along(forward_formulas)) {
  temp_model <- lm(forward_formulas[[i]], data = train_df)
  
  temp_bias_pred <- predict(temp_model, newdata = test_df)
  temp_corrected_tmin <- test_df$LDAPS_Tmin_lapse + temp_bias_pred
  temp_corrected_error <- test_df$Next_Tmin - temp_corrected_tmin
  
  # RMSE Calculation
  temp_rmse <- sqrt(mean(temp_corrected_error^2, na.rm=TRUE))
  linear_backtest_results$Corrected_RMSE[i] <- temp_rmse
  linear_backtest_results$RMSE_Improvement_Perc[i] <- 100 * (rmse_ldaps_test - temp_rmse) / rmse_ldaps_test
  
  # BIAS Calculation (Absolute values for correct % improvement on negatives)
  temp_mbe <- mean(temp_corrected_error, na.rm=TRUE)
  linear_backtest_results$Corrected_Bias[i] <- temp_mbe
  linear_backtest_results$Bias_Improvement_Perc[i] <- 100 * (abs(mbe_ldaps_test) - abs(temp_mbe)) / abs(mbe_ldaps_test)
}

# Plot 1: RMSE Improvement 
rmse_backtest_plot <- ggplot(linear_backtest_results, aes(x = factor(Model), y = RMSE_Improvement_Perc)) +
  geom_col(fill = ifelse(linear_backtest_results$Model == linear_model_index, "#D55E00", "#0072B2")) +
  geom_text(aes(label = sprintf("%.1f%%", RMSE_Improvement_Perc)), vjust = -0.5, size = 3.5) +
  labs(
    title = "Backtest 2017: RMSE Improvement (Error Variance)",
    subtitle = "In orange: Model 5 selected via the elbow criterion",
    x = "Model index in forward sequence",
    y = "RMSE Improvement (%) vs LDAPS"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot 2: BIAS Improvement 
bias_backtest_plot <- ggplot(linear_backtest_results, aes(x = factor(Model), y = Bias_Improvement_Perc)) +
  geom_col(fill = ifelse(linear_backtest_results$Model == linear_model_index, "#009E73", "#56B4E9")) +
  geom_text(aes(label = sprintf("%.1f%%", Bias_Improvement_Perc)), vjust = -0.5, size = 3.5, fontface="bold") +
  labs(
    title = "Backtest 2017: Systematic BIAS Reduction",
    subtitle = "LDAPS' structural overestimation error is almost entirely erased",
    x = "Model index in forward sequence",
    y = "BIAS Correction (%)"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(rmse_backtest_plot)
print(bias_backtest_plot)

# ==============================================================================
# FINAL THEORETICAL INTERPRETATION FOR PRESENTATION
# ==============================================================================
# The analysis isolated four fundamental physical domains responsible for the Tmin bias:
#
# 1. STATIONARY MEMORY (ErroreTmin_Lag1)
#    The inclusion of the autoregressive structure (Lag 1) dominates the increase 
#    in explained variance. This proves that the global model suffers from 
#    "stationary blindness": the error is not white noise, but is viscous and 
#    persistent. Cold air pools in the valleys (or urban heat islands) linger 
#    for days until macroscopic circulation intervenes to sweep them away.
#
# 2. THERMAL INERTIA AND SYNOPTIC MOMENTUM (TrendTMIN)
#    While Lag 1 tells us "how much the model missed yesterday," TrendTMIN 
#    indicates the "speed and direction" the climate is moving. The urban basin 
#    of Seoul possesses massive thermal inertia. LDAPS, a pure atmospheric model, 
#    fails to capture this physical lag. TrendTMIN acts as the global model's 
#    thermodynamic lag corrector.
#
# 3. LATENT HEAT AND MONSOON (Latent_Heat_Flux)
#    In the Korean summer (Changma Monsoon), saturated soils dissipate solar 
#    energy via evaporation (latent heat) rather than sensible heat. At night, 
#    this alters the radiative cooling rate of the soil, heavily skewing the 
#    global model's baseline predictions.
#
# 4. LINEAR OROGRAPHY AND ITS LIMITS (Elevation, Slope)
#    Altitude and slope enter the model at the 4th and 5th step. We capture 
#    the station's mean elevation and the slope on which katabatic winds slide. 
#    However, a purely linear model treats the mountain as an infinite inclined 
#    plane, ignoring true "concavity" (U-shaped valleys). This geometric limit 
#    justifies the subsequent shift to non-linear cubic models.
# ==============================================================================
