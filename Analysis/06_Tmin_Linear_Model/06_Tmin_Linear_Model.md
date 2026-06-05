# Section 6: Baseline Linear Model for Tmin Correction

**Objective:**
To construct a parsimonious baseline multiple linear regression model that corrects the Minimum Temperature (Tmin) nighttime bias, utilizing strict feature selection (AIC) and variance penalization algorithms.

**Physical/Theoretical Meaning:**
Through Automated Forward Selection, we allowed the algorithm to rank variables based on error reduction. However, to prevent algebraic overfitting, we applied the **"Elbow Rule" on the Adjusted R-squared metric**, establishing an optimal cut-off at **Model 5**. This specific cut-off is not just mathematically optimal; it encapsulates three fundamental physical domains of the Seoul basin that the global LDAPS model ignores:
1. **Stationary Memory (`ErroreTmin_Lag1`):** The error is "viscous". Cold air pools in the valleys persist for days. The lag gives the model an autoregressive memory.
2. **Energy Exchange & Momentum (`TrendTMIN` & `Latent_Heat_Flux`):** Accounts for the urban concrete's thermal inertia and the evaporative energy dissipation during the humid Changma monsoon.
3. **Linear Orography (`Elevation` & `Slope`):** Factors in the altitude and the inclination slope facilitating the flow of nighttime katabatic winds.

*Note: While Model 5 represents a fantastic baseline, treating the mountain as a flat "inclined plane" (linear) ignores the true 3D concavity of the valleys. This limit will be explored in the Non-Linear section.*

**Key Results (Metrics extracted from Model 5 Backtest 2017):**
* **In-Sample Optimization:** Reached an Adjusted R-squared of **24.95%**. Variables selected after Model 5 provided only negligible gains ($< 0.5\%$), triggering the parsimony cut.
* **Variance Reduction (RMSE):** Out-of-sample RMSE improved from **1.2310 °C to 0.9413 °C** (a solid **23.54% improvement**).
* **Systematic Error Eradication (BIAS):** This is the crown jewel of the linear model. The initial Mean Bias Error (MBE) of **-0.6302 °C** (a chronic overestimation of nighttime temperatures) was crushed down to **-0.0366 °C**. The linear model wiped out **94.20%** of the global model's structural defect, perfectly centering the prediction aim.

**Graph Placeholders:**
[INSERT PLOT: Elbow Rule for Adjusted R-squared]
[INSERT PLOT: Linear Model Diagnostics (4 subplots: Residuals, Q-Q, Scale-Location, Cook's Distance)]
[INSERT PLOT: Scatter Plot - Absolute Error LDAPS vs Model 5 on Test Set]
[INSERT PLOT: Bar Chart - Backtest RMSE Improvement across 14 models]
[INSERT PLOT: Bar Chart - Backtest BIAS Reduction across 14 models]
