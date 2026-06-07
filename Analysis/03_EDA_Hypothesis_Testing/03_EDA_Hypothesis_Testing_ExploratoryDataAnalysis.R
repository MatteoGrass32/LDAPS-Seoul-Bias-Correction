# ==============================================================================
# PART 1: ENVIRONMENT SETUP AND DATA IMPORT
# ------------------------------------------------------------------------------
# This section initializes the R workspace, loads required statistical and 
# visualization packages, and imports the clean meteorological dataset.
# ==============================================================================

library(Metrics)
library(car)
library(rgl)
library(MASS)
library(leaps)
library(GGally)
library(ellipse)
library(faraway)
library(ggplot2)
library(gridExtra)

Dati <- read.csv("DataSetWithErrors.csv")

# ==============================================================================
# PART 2: INITIAL DATA QUALITY CHECKS
# ------------------------------------------------------------------------------
# Before analyzing the data, we verify the integrity of the dataset by 
# checking data types and looking for missing values (NAs). 
# Meteorological datasets often suffer from sensor failures or missing 
# transmission data, so ensuring a clean dataset is crucial for valid modeling.
# ==============================================================================

summary(Dati)
sum(is.na(Dati))
sapply(Dati, function(x) any(is.na(x)))
sapply(Dati, typeof)

# ==============================================================================
# PART 3: TARGET VARIABLES & UNIVARIATE ANALYSIS (DISTRIBUTIONS)
# ------------------------------------------------------------------------------
# Here we define and analyze the forecast errors for Maximum Temperature (Tmax), 
# Minimum Temperature (Tmin), and the Diurnal Temperature Range (DTR).
#
# METEOROLOGICAL FACT: 
# Models often struggle differently with Tmax and Tmin. Tmax is heavily dependent 
# on solar radiation and sensible heat flux during the day, while Tmin is driven 
# by radiational cooling at night. Furthermore, the Diurnal Temperature Range 
# (DTR = Tmax - Tmin) is highly sensitive to cloud cover and soil moisture. 
# A model incorrectly predicting a clear night instead of an overcast one will 
# heavily underestimate Tmin and overestimate the DTR.
# ==============================================================================

Emax <- Dati$Error_Tmax
Emin <- Dati$Error_Tmin

par(mfrow = c(1, 2))
hist(Emax, main = "Histogram of Tmax Error", xlab = "Tmax Error (°C)", col = "lightblue")
boxplot(Emax, main = "Boxplot of Tmax Error", ylab = "Error (°C)", col = "lightblue")

par(mfrow = c(1, 2))
hist(Emin, main = "Histogram of Tmin Error", xlab = "Tmin Error (°C)", col = "mistyrose")
boxplot(Emin, main = "Boxplot of Tmin Error", ylab = "Error (°C)", col = "mistyrose")

par(mfrow = c(1, 1))

escursione_Prev <- Dati$LDAPS_Tmax_lapse - Dati$LDAPS_Tmin_lapse
escursione_Obs <- Dati$Next_Tmax - Dati$Next_Tmin
Errore_esc <- -escursione_Prev + escursione_Obs

par(mfrow = c(1, 2))
hist(Errore_esc, main = "DTR Error Distribution", xlab = "DTR Error (°C)", col = "lightgreen")
boxplot(Errore_esc, main = "DTR Error Boxplot", ylab = "Error (°C)", col = "lightgreen")
summary(Errore_esc)

par(mfrow = c(1, 1))
boxplot(Emax, Emin, Errore_esc, names = c("Tmax Error", "Tmin Error", "DTR Error"), 
        main = "Comparison of Forecasting Errors", col = c("lightblue", "mistyrose", "lightgreen"))
abline(h = 0, col = "red", lty = 2)

# ==============================================================================
# PART 4: BIVARIATE ANALYSIS & CORRELATIONS
# ------------------------------------------------------------------------------
# We use scatterplots and correlation matrices to understand how observed values 
# relate to predicted ones, and how different atmospheric variables interact.
#
# METEOROLOGICAL FACT: 
# Meteorological variables are physically coupled. For example, if a weather model 
# underestimates incoming shortwave radiation (sunlight), it will likely predict 
# a Tmax that is too low. Examining the correlation between different forecast 
# errors can reveal systemic biases in the numerical weather prediction (NWP) model.
# ==============================================================================

par(mfrow = c(1, 2))
plot(Dati$Next_Tmax, Dati$LDAPS_Tmax_lapse, main = "Tmax: Observed vs Predicted")
abline(a = 0, b = 1, col = "red", lwd = 2, lty = 2)

plot(Dati$Next_Tmin, Dati$LDAPS_Tmin_lapse, main = "Tmin: Observed vs Predicted")
abline(a = 0, b = 1, col = "red", lwd = 2, lty = 2)

par(mfrow = c(1, 1))

variabili_meteo <- c("Next_Tmax", "LDAPS_Tmax_lapse", "Error_Tmax", "Error_Tmin", "DEM", "Slope")
available_vars <- variabili_meteo[variabili_meteo %in% colnames(Dati)]

pairs(Dati[, available_vars], pch = 1, main = "Scatterplot Matrix of Key Variables")
ggcorr(Dati[, available_vars], label = TRUE, label_round = 2, main = "Correlation Matrix")

# ==============================================================================
# PART 5: TOPOGRAPHICAL IMPACT (ALTITUDE / DEM)
# ------------------------------------------------------------------------------
# This section investigates how the model's accuracy changes with elevation (DEM).
#
# METEOROLOGICAL FACT: 
# In the troposphere, temperature typically decreases with altitude at an average 
# environmental lapse rate of ~6.5°C per 1000m. However, global/regional models 
# often have coarse spatial resolutions that "smooth out" actual topography. 
# Because of this, models frequently miscalculate temperatures in valleys 
# (missing cold air pools/inversions at night, leading to huge Tmin errors) 
# and underestimate extreme cold on jagged mountain peaks.
# ==============================================================================

boxplot(Dati$Error_Tmax ~ factor(Dati$station), main = "Tmax Error by Station")
abline(h = 0, col = "red", lty = 2)
boxplot(Dati$Error_Tmin ~ factor(Dati$station), main = "Tmin Error by Station")
abline(h = 0, col = "red", lty = 2)

limiti_y <- c(-7, 7)
par(mfrow = c(1, 2))
plot(Dati$DEM, Emax, ylim = limiti_y, main = "Tmax Error vs Altitude")
abline(h = 0, col = "red", lty = 2)

plot(Dati$DEM, Emin, ylim = limiti_y, main = "Tmin Error vs Altitude")
abline(h = 0, col = "red", lty = 2)

par(mfrow = c(1, 1))

p_max_err <- ggplot(Dati, aes(x = DEM, y = abs(Error_Tmax))) + 
  geom_point(color = "blue", alpha = 0.2) +
  geom_smooth(method = "loess", color = "darkblue", size = 1.2) +
  labs(title = "Impact of Altitude on Absolute Tmax Error", x = "Altitude (DEM)", y = "Absolute Tmax Error (°C)") +
  theme_minimal()

p_min_err <- ggplot(Dati, aes(x = DEM, y = abs(Error_Tmin))) +
  geom_point(color = "red", alpha = 0.2) +
  geom_smooth(method = "loess", color = "darkred", size = 1.2) +
  labs(title = "Impact of Altitude on Absolute Tmin Error", x = "Altitude (DEM)", y = "Absolute Tmin Error (°C)") +
  theme_minimal()

grid.arrange(p_max_err, p_min_err, ncol = 2)

Dati$DEM_classi <- cut(Dati$DEM, breaks = seq(0, max(Dati$DEM, na.rm = TRUE) + 50, by = 50))

par(mfrow = c(1, 2))
boxplot(Error_Tmax ~ DEM_classi, data = Dati, col = "lightblue", main = "Tmax Error by Altitude Range", las = 2, cex.axis = 0.8)
abline(h = 0, col = "red", lty = 2)

boxplot(Error_Tmin ~ DEM_classi, data = Dati, col = "mistyrose", main = "Tmin Error by Altitude Range", las = 2, cex.axis = 0.8)
abline(h = 0, col = "red", lty = 2)

par(mfrow = c(1, 1))