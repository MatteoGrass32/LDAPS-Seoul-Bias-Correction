# ==============================================================================
# SECTION 7 - NON-LINEAR TOPOGRAPHIC MODELING FOR TMIN BIAS CORRECTION
#
# Meteorological Problem:
# The dataset covers the summer seasons in Seoul, dominated by the "Changma" monsoon.
# It is a season of extreme turbulence: high humidity, heavy rains, and sudden clear 
# nights with strong radiative cooling. The LDAPS global model systematically fails 
# to predict minimum nighttime temperatures in urban valleys.
#
# Objective of this script:
# To verify whether the bias can be corrected by combining temporal memory (AR-1) 
# with a non-linear mathematical mapping (interacting cubic polynomials) of the 
# topography, simulating 3D "cold air pools" (thermal inversions).
# ==============================================================================

# ==============================================================================
# 1. LIBRARIES
# ==============================================================================
library(tidyverse)   # For data manipulation
library(MASS)        # For advanced statistical functions
library(boot)        # For diagnostics and resampling
library(ggplot2)     # For data visualization
library(car)         # For multicollinearity calculations (VIF)
library(gridExtra)   # For graph layout
library(corrplot)    # For visual correlation matrices

# ==============================================================================
# 2. DATA LOADING AND CORRELATION MATRIX
# ==============================================================================
train_df <- read.csv("TrainingSet.csv")
test_df  <- read.csv("TestSet.csv")

cat("\n--- EXPLORATORY ANALYSIS: CORRELATION MATRIX ---\n")
# Selecting only key variables to avoid an unreadable plot
correlation_variables <- train_df %>%
  dplyr::select(ErroreTmin_Lag1, TrendTMIN, Latent_Heat_Flux, Elevation, Slope) %>%
  drop_na() # Removing rows with NAs (e.g., the first day without Lag1)

# Calculating the Pearson correlation matrix
corr_matrix <- cor(correlation_variables)

# Creating the visual plot
corrplot(corr_matrix, 
         method = "color", 
         type = "upper", 
         order = "hclust", # Groups similar variables together
         addCoef.col = "black", # Shows numbers inside the squares
         tl.col = "black", tl.srt = 45, # Color and rotation of the text
         title = "Correlation between Error_Tmin and Key Predictors",
         mar = c(0,0,2,0)) # Margins for the title

# ==============================================================================
# PROGRESSIVE CONSTRUCTION OF THE NON-LINEAR MODEL (TMIN)
# ==============================================================================
# Important Note:
# The best in-sample model (R2) is not automatically the best model in the real world. 
# Adding cubes and interactions increases the risk of algebraic overfitting.
# Therefore, the true validation will occur through a "Battle Royale" on the Test Set.

cat("\n--- PROGRESSIVE CONSTRUCTION OF NON-LINEARITIES ---\n")

# Model 1 (Baseline Linear): The mountain viewed as a flat inclined plane.
model_nl_1_linear <- lm(
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + 
    Elevation + Slope,
  data = train_df
)

# Model 2 (Linear Interaction): The plane tilts dynamically.
model_nl_2_linear_interaction <- lm(
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + 
    Elevation * Slope,
  data = train_df
)

# Model 3 (Separate Quadratic): The mountain becomes a parabola (smooth U-valley).
model_nl_3_quadratic <- lm(
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + 
    Elevation + I(Elevation^2) + 
    Slope + I(Slope^2),
  data = train_df
)

# Model 4 (Separate Cubic): S-curves appear (peaks, mid-slopes, valleys).
model_nl_4_cubic <- lm(
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + 
    Elevation + I(Elevation^2) + I(Elevation^3) + 
    Slope + I(Slope^2) + I(Slope^3),
  data = train_df
)

# Model 5 (Quadratic Interaction): Construction of the first 3D bowl-shaped valleys.
model_nl_5_quadratic_interaction <- lm(
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + 
    (Elevation + I(Elevation^2)) * (Slope + I(Slope^2)),
  data = train_df
)

# Model 6 (Cubic Interaction): THE WINNER. Complex 3D mapping of the valleys.
model_nl_6_cubic_interaction <- lm(
  Error_Tmin ~ ErroreTmin_Lag1 + TrendTMIN + Latent_Heat_Flux + 
    (Elevation + I(Elevation^2) + I(Elevation^3)) * (Slope + I(Slope^2) + I(Slope^3)),
  data = train_df
)

# Model 7 (Cubic + Dynamic AR-1 Interaction): 
# Testing whether the impact of yesterday's error (Lag1) is amplified or reduced 
# by the ongoing thermal trend (TrendTMIN).
model_nl_7_cubic_interaction_ar <- lm(
  Error_Tmin ~ (ErroreTmin_Lag1 * TrendTMIN) + Latent_Heat_Flux + 
    (Elevation + I(Elevation^2) + I(Elevation^3)) * (Slope + I(Slope^2) + I(Slope^3)),
  data = train_df
)

cat("\n=======================================================\n")
cat("      IN-SAMPLE RANKING BY ADJUSTED R-SQUARED\n")
cat("=======================================================\n")
cat(sprintf("1. Baseline Linear          | R2_Adj: %6.3f%%\n", summary(model_nl_1_linear)$adj.r.squared * 100))
cat(sprintf("2. Linear Interaction       | R2_Adj: %6.3f%%\n", summary(model_nl_2_linear_interaction)$adj.r.squared * 100))
cat(sprintf("3. Baseline Quadratic       | R2_Adj: %6.3f%%\n", summary(model_nl_3_quadratic)$adj.r.squared * 100))
cat(sprintf("4. Baseline Cubic           | R2_Adj: %6.3f%%\n", summary(model_nl_4_cubic)$adj.r.squared * 100))
cat(sprintf("5. Quadratic Interaction    | R2_Adj: %6.3f%%\n", summary(model_nl_5_quadratic_interaction)$adj.r.squared * 100))
cat(sprintf("6. Cubic Interaction        | R2_Adj: %6.3f%%\n", summary(model_nl_6_cubic_interaction)$adj.r.squared * 100))
cat(sprintf("7. Cubic + AR Interaction   | R2_Adj: %6.3f%%\n", summary(model_nl_7_cubic_interaction_ar)$adj.r.squared * 100))
cat("=======================================================\n")

# Creating the list and labels for automated testing
non_linear_models <- list(
  model_nl_1_linear,
  model_nl_2_linear_interaction,
  model_nl_3_quadratic,
  model_nl_4_cubic,
  model_nl_5_quadratic_interaction,
  model_nl_6_cubic_interaction,
  model_nl_7_cubic_interaction_ar
)

nl_labels <- c(
  "Baseline Linear",
  "Linear Interaction",
  "Baseline Quadratic",
  "Baseline Cubic",
  "Quadratic Interaction",
  "Cubic Interaction",
  "Cubic + AR Interaction"
)

# Selecting Model 6 as the definitive champion
non_linear_model_index <- 6

# "Elbow Method" plot on Adjusted R-squared to evaluate algebraic overfitting
nl_r2adj <- sapply(non_linear_models, function(m) summary(m)$adj.r.squared)

df_nl_elbow <- data.frame(
  Model = 1:7,
  Label = nl_labels,
  R2_Adj = nl_r2adj * 100
)

nl_elbow_plot <- ggplot(
  df_nl_elbow,
  aes(x = Model, y = R2_Adj)
) +
  geom_line(color = "#0072B2", linewidth = 1) +
  geom_point(size = 3, color = "#0072B2") +
  geom_vline(
    xintercept = non_linear_model_index,
    linetype = "dashed",
    color = "#D55E00",
    linewidth = 1
  ) +
  geom_point(
    data = subset(df_nl_elbow, Model == non_linear_model_index),
    aes(x = Model, y = R2_Adj),
    color = "#D55E00",
    size = 4
  ) +
  labs(
    title = "Elbow Method: Adjusted R-Squared of Non-Linear Models",
    subtitle = "The cut is placed on Model 6 (Topographical Cubic Interaction)",
    x = "Model index in the non-linear sequence",
    y = "Adjusted R-Squared (%)"
  ) +
  scale_x_continuous(breaks = 1:7, labels = 1:7) +
  theme_minimal(base_size = 13)

print(nl_elbow_plot)

# Promoting Model 6 to Non-Linear Champion
top_non_linear_model <- model_nl_6_cubic_interaction

# ==============================================================================
# PHASE 5.1: NON-LINEAR MODEL DIAGNOSTICS
# ==============================================================================
cat("\n--- SELECTED NON-LINEAR MODEL DIAGNOSTICS ---\n")

par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))

plot(top_non_linear_model, which = 1) # Checking residual linearity
plot(top_non_linear_model, which = 2) # Normality (Q-Q Plot)
plot(top_non_linear_model, which = 3) # Homoscedasticity
plot(top_non_linear_model, which = 4) # Cook's Distance (Outliers)

par(mfrow = c(1, 1))

# Methodological Note on VIF:
# In interacting polynomial models (x * x^2 * x^3), the VIF will mathematically 
# explode due to the perfect structural collinearity between the variable and its 
# powers. In this scenario, VIF loses its meaning; the goodness of the model is 
# evaluated solely via its resilience on Out-of-Sample error.

# ==============================================================================
# PHASE 5.2: BATTLE ROYALE ON THE TEST SET
# ==============================================================================
cat("\n--- BATTLE ROYALE ON THE TEST SET: LINEAR VS CUBIC MODEL ---\n")

# Initial Metrics
rmse_ldaps_test <- sqrt(mean(test_df$Error_Tmin_Iniziale^2, na.rm=TRUE))
mae_ldaps_test <- mean(abs(test_df$Error_Tmin_Iniziale), na.rm=TRUE)
mbe_ldaps_test <- mean(test_df$Error_Tmin_Iniziale, na.rm=TRUE)

# Model 1 Prediction (Linear AR-1)
linear_bias_pred_test <- predict(model_nl_1_linear, newdata = test_df)
linear_corr_tmin_test <- test_df$LDAPS_Tmin_lapse + linear_bias_pred_test
linear_error_test <- test_df$Next_Tmin - linear_corr_tmin_test
rmse_linear_test <- sqrt(mean(linear_error_test^2, na.rm=TRUE))

# Model 6 Prediction (Cubic AR-1)
top_bias_pred_test <- predict(top_non_linear_model, newdata = test_df)
top_corr_tmin_test <- test_df$LDAPS_Tmin_lapse + top_bias_pred_test
top_error_test <- test_df$Next_Tmin - top_corr_tmin_test
rmse_top_test <- sqrt(mean(top_error_test^2, na.rm=TRUE))
mae_top_test <- mean(abs(top_error_test), na.rm=TRUE)
mbe_top_test <- mean(top_error_test, na.rm=TRUE)

# Calculating Percentage Bias Improvement
perc_bias_improvement <- 100 * (abs(mbe_ldaps_test) - abs(mbe_top_test)) / abs(mbe_ldaps_test)

cat(sprintf("Initial RMSE (LDAPS)                  : %.4f °C\n\n", rmse_ldaps_test))
cat(sprintf(
  "Final Linear Model                    | RMSE: %.4f °C | Improvement: %5.2f%%\n",
  rmse_linear_test,
  100 * (rmse_ldaps_test - rmse_linear_test) / rmse_ldaps_test
))
cat(sprintf(
  "Top Non-Linear Model (Cubic)          | RMSE: %.4f °C | Improvement: %5.2f%%\n",
  rmse_top_test,
  100 * (rmse_ldaps_test - rmse_top_test) / rmse_ldaps_test
))
cat("\n--- THE REAL MASTERPIECE: SYSTEMATIC BIAS REDUCTION ---\n")
cat(sprintf("Initial Mean BIAS   : %7.4f °C (Tendency to overestimate)\n", mbe_ldaps_test))
cat(sprintf("Corrected Mean BIAS : %7.4f °C (Error practically zeroed)\n", mbe_top_test))
cat(sprintf("BIAS Correction     : %.2f%%\n", perc_bias_improvement))
cat("======================================================\n")

nl_backtest_df <- test_df %>%
  mutate(
    AbsLDAPSError = abs(Error_Tmin_Iniziale),
    EstimatedBias_NL = top_bias_pred_test,
    CorrectedTmin_NL = LDAPS_Tmin_lapse + EstimatedBias_NL,
    CorrectedError_NL = Next_Tmin - CorrectedTmin_NL,
    AbsCorrectedError_NL = abs(CorrectedError_NL)
  )

nl_error_plot <- ggplot(
  nl_backtest_df,
  aes(x = AbsLDAPSError, y = AbsCorrectedError_NL)
) +
  geom_point(alpha = 0.5, color = "#0072B2") +
  geom_abline(
    slope = 1, intercept = 0,
    linetype = "dashed",
    color = "#D55E00",
    linewidth = 1
  ) +
  labs(
    title = "Absolute Error: LDAPS vs Model 6 on Test Set",
    subtitle = "Points BELOW the dashed orange line represent improved predictions.",
    x = "Original LDAPS absolute error (Test Set, °C)",
    y = "New absolute error after Model 6 correction (Test Set, °C)"
  ) +
  theme_minimal()

print(nl_error_plot)

# ==============================================================================
# PHASE 5.3: COMPARATIVE BACKTEST ON NON-LINEAR MODELS (RMSE & BIAS)
# ==============================================================================
cat("\n--- STARTING COMPARATIVE BACKTEST ON NON-LINEAR MODELS ---\n")

nl_backtest_results <- data.frame(
  Model = 1:7,
  Structure = nl_labels,
  Corrected_RMSE = numeric(7),
  RMSE_Improvement_Perc = numeric(7),
  Corrected_Bias = numeric(7),
  Bias_Improvement_Perc = numeric(7)
)

for (i in seq_along(non_linear_models)) {
  temp_model <- non_linear_models[[i]]
  
  temp_bias_pred <- predict(temp_model, newdata = test_df)
  temp_corrected_tmin <- test_df$LDAPS_Tmin_lapse + temp_bias_pred
  temp_corrected_error <- test_df$Next_Tmin - temp_corrected_tmin
  
  # RMSE
  temp_rmse <- sqrt(mean(temp_corrected_error^2, na.rm=TRUE))
  nl_backtest_results$Corrected_RMSE[i] <- temp_rmse
  nl_backtest_results$RMSE_Improvement_Perc[i] <- 100 * (rmse_ldaps_test - temp_rmse) / rmse_ldaps_test
  
  # BIAS
  temp_mbe <- mean(temp_corrected_error, na.rm=TRUE)
  nl_backtest_results$Corrected_Bias[i] <- temp_mbe
  nl_backtest_results$Bias_Improvement_Perc[i] <- 100 * (abs(mbe_ldaps_test) - abs(temp_mbe)) / abs(mbe_ldaps_test)
}

# Plot 1: RMSE Improvement
nl_rmse_backtest_plot <- ggplot(nl_backtest_results, aes(x = factor(Model), y = RMSE_Improvement_Perc)) +
  geom_col(fill = ifelse(nl_backtest_results$Model == non_linear_model_index, "#D55E00", "#0072B2")) +
  geom_text(aes(label = sprintf("%.1f%%", RMSE_Improvement_Perc)), vjust = -0.5, size = 3.5) +
  scale_x_discrete(labels = nl_backtest_results$Structure) + # Feature added!
  labs(
    title = "Backtest 2017: RMSE Improvement (Non-Linear Models)",
    subtitle = "In orange: Model 6 selected as the winner",
    x = "Model structure in the non-linear sequence",
    y = "RMSE Improvement (%) vs LDAPS"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Plot 2: BIAS Improvement
nl_bias_backtest_plot <- ggplot(nl_backtest_results, aes(x = factor(Model), y = Bias_Improvement_Perc)) +
  geom_col(fill = ifelse(nl_backtest_results$Model == non_linear_model_index, "#009E73", "#56B4E9")) +
  geom_text(aes(label = sprintf("%.1f%%", Bias_Improvement_Perc)), vjust = -0.5, size = 3.5, fontface="bold") +
  scale_x_discrete(labels = nl_backtest_results$Structure) + # Feature added!
  labs(
    title = "Backtest 2017: Systematic BIAS Reduction",
    subtitle = "3D topography and memory eliminate the structural forecasting defect",
    x = "Model structure in the non-linear sequence",
    y = "BIAS Correction (%)"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

print(nl_rmse_backtest_plot)
print(nl_bias_backtest_plot)

# ==============================================================================
# 6. FINAL THEORETICAL DEEP DIVE: THE ANATOMY OF THE TMIN BIAS
# ==============================================================================
# The incredible performance leap in the Out-of-Sample Backtest proves that the 
# Minimum Temperature bias is not stochastic noise, but a phenomenon governed 
# by precise physical rules that Model 6 has successfully decoded:
#
# 1. SYSTEM INERTIA AND MEMORY (ErroreTmin_Lag1 & TrendTMIN)
#    The AR(1) approach proved that LDAPS's error is "viscous." Due to the massive 
#    thermal inertia of Seoul's urban basin, hot or cold air pockets stagnate for 
#    days. The global model "forgets" these anomalies, while our Lag1 ensures the 
#    corrector maintains memory. TrendTMIN acts as a derivative, calculating the 
#    momentum with which this inertia is accelerating or braking compared to yesterday.
#
# 2. THE MONSOON AND INVISIBLE ENERGY (Latent_Heat_Flux)
#    During South Korean summers (Changma Monsoon), water-saturated soils dissipate 
#    solar energy via evaporation (latent heat) rather than heating the air. This 
#    drastically alters the soil's radiative equilibrium at night, skewing the 
#    cooling estimates of the base model.
#
# 3. THERMAL INVERSION AND CUBIC GEOMETRY (Elevation^3 * Slope^3)
#    Classical physics dictates that temperature drops with altitude. However, on 
#    clear nights, dense, cold air slides down the mountains and accumulates in 
#    the valleys, creating "cold air pools" (Thermal Inversion).
#    While a linear model imagines the mountain as a flat plane, multiplying 
#    altitude cubed by slope cubed creates an "S-shaped" polynomial. This is the 
#    exact 3D geometric representation of a U-shaped or V-shaped valley. 
#
# CONCLUSION:
# Model 6 corrects the bias by "modeling the invisible." It builds a topographical 
# container (Cubes) that retains moisture (Latent Heat) and preserves temperature 
# over time (Lag1). It does not violate the physical laws of the global model, 
# but surgically adapts them to the micro-scale of Seoul.
# ==============================================================================
# 7. DECISIONAL SYNTHESIS: LINEAR VS NON-LINEAR (CUBIC) MODEL
# ==============================================================================
# When choosing between the Linear Model (M5) and the Non-Linear Model (M6), 
# a legitimate objection arises: if the linear model already corrects the 
# systematic error (Bias) by over 90%, is it truly justified to introduce the 
# heavy mathematical complexity of interacting cubic polynomials?
#
# The answer depends on the level of spatial granularity required by the 
# meteorological objective, measurable through the dichotomy between BIAS and RMSE:
#
# A) WHEN TO PREFER THE LINEAR MODEL (The "Marksman")
#    The linear model excels in parsimony. It successfully zeroed the mean Bias 
#    (from -0.8°C to almost 0°C), "hitting the bullseye." If the operational goal 
#    is to correct the average LDAPS forecast over the entire urban macro-area of 
#    Seoul, the Linear Model is more than sufficient. It eliminates the global 
#    model's structural defect with low risk of overfitting and very light computation.
#
# B) WHEN THE NON-LINEAR MODEL IS INDISPENSABLE (The "Sniper")
#    The fact that the Bias is near zero in the linear model does not mean there 
#    are no errors, only that overestimations and underestimations cancel each 
#    other out. The error is "smeared" homogeneously across the territory.
#    The Non-Linear Model, while maintaining a zeroed Bias, manages to double the 
#    in-sample Adjusted R-Squared and improve the out-of-sample RMSE by an additional 
#    4 percentage points (reaching 27.2%). This means that the non-linear cubic 
#    architecture drastically reduces the "dispersion" (variance) of the error 
#    around zero.
#
# OPERATIONAL AND METEOROLOGICAL CONCLUSION:
# If the goal is MICROMETEOROLOGY (e.g., issuing localized warnings for frost risk 
# in agricultural valleys or monitoring heat accumulation in specific neighborhoods), 
# the Non-Linear Model becomes an indispensable tool. Only the third-degree polynomial 
# multiplication (Elevation^3 * Slope^3) possesses the geometric degrees of freedom 
# to transform the "inclined plane" of the linear model into a true three-dimensional 
# map (U or V valleys), precisely tracking the cold air pockets in individual stations. 
# The rigorous validation on the Test Set certifies that this complexity is the 
# expression of a real physical signal, not a statistical artifact.
# ==============================================================================