# Section 1: Project Overview & Objectives

**Objective:**
To statistically post-process and correct the systematic thermal bias of the LDAPS (Local Data Assimilation and Prediction System) weather forecasting model over the urban basin of Seoul, South Korea.

**Physical/Theoretical Meaning:**
Numerical Weather Prediction (NWP) models like LDAPS are incredibly powerful at a macro scale, but they often fail to capture micro-meteorological phenomena constrained by complex urban topography. Our mission is to bridge the gap between physics and statistics:
* **The Goal:** Enhance the predictive accuracy of tomorrow's extreme temperatures (Minimum and Maximum) by learning from the model's past mistakes.
* **The Methodology:** We employ a progressive statistical approach (from baseline Linear models to Non-Linear Polynomial interactions). We strictly penalize algebraic overfitting using the **Adjusted R-squared** metric and validate performance out-of-sample (Backtesting). 
* **The Physical Constraint:** Every mathematical feature added (e.g., cubic topography, autoregressive lags) must have a rigorous meteorological justification. We are not just blindly reducing variance; we are modeling physical realities that LDAPS ignores.
* **The Dual-Track Architecture:** The physics of daytime heating and nighttime cooling are fundamentally different. Therefore, the project runs on two entirely independent modeling tracks: one dedicated to **Tmax** (driven by solar radiation and sensible heat) and one to **Tmin** (driven by thermal inversions and drainage flows).

**Key Features of the Analysis:**
* Transitioning from a flat 2D grid approach to a 3D topographic modeling of the urban basin.
* Integration of Autoregressive (AR) memory to capture atmospheric thermal inertia.
* Strict evaluation based on RMSE (variance reduction) and Mean Bias Error (systematic flaw correction).

**Graph Placeholders:**