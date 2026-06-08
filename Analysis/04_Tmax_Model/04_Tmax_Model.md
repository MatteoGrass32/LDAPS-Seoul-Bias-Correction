# Section: Baseline Linear Model for Tmax Correction

**Objective:** To construct a parsimonious baseline multiple linear regression model that corrects the Maximum Temperature (Tmax) daytime bias, utilizing a greedy Forward Selection algorithm guided by variance penalization.

**Physical/Theoretical Meaning:** Through Automated Forward Selection, we allowed the algorithm to rank variables based on error reduction. However, to prevent algebraic overfitting, we applied the "Elbow Rule" on the Adjusted R-squared metric, establishing an optimal cut-off at **Model 5**. This specific cut-off encapsulates two fundamental physical domains driving daytime heating that the global LDAPS model miscalculates:
* **Stationary Memory (`ErroreTmax_Lag1`, `ErroreTmax_Lag3`, `ErroreTmax_Lag5`):** The error exhibits strong multi-day inertia. The lag gives the model an autoregressive memory, learning the LDAPS model's repeated failure to capture consecutive daytime heat waves or cooling trends.
* **Radiative & Atmospheric Dynamics (`Cloud_Cover_Avg` & `RelativeHumidity_Min`):** Cloud cover strictly dictates the amount of shortwave solar radiation reaching the urban surface. Simultaneously, minimum relative humidity strongly correlates with peak afternoon heating capacity (drier air heats much more rapidly).

*Note: While Model 5 represents an excellent baseline, it relies entirely on linear relationships, potentially missing complex non-linear meteorological interactions.*

**Key Results (Metrics extracted from Model 5 Backtest):**
* **In-Sample Optimization:** Reached an Adjusted R-squared of **24.62%**. Variables selected after Model 5 provided only negligible gains, triggering the parsimony cut to prevent overfitting.
* **Variance Reduction (RMSE):** Out-of-sample RMSE improved from **1.8696 °C to 1.7351 °C** (a solid **7.19% improvement** over the baseline).
* **Systematic Error Eradication (BIAS):** The initial Mean Bias Error (MBE) of **-0.3513 °C** (a chronic underestimation of daytime peak temperatures) was corrected to **+0.2531 °C**. The 5-variable linear model wiped out **27.93%** of the global model's structural bias defect.


