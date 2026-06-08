# 🌤️ LDAPS Seoul Thermal Bias Correction
**Statistical and machine learning pipeline to correct the thermal bias of the Local Data Assimilation and Prediction System (LADPS) weather forecasting model in Seoul. Developed for the Mathematical Engineering program at Politecnico di Milano.**

## Authors:
Matteo Grassini, Alice Rossato, Andrea Santimaria

## 📖 Project Overview
Numerical Weather Prediction (NWP) models are the backbone of modern meteorology, but they struggle to capture micro-scale topographical features. This project focuses on the **Local Data Assimilation and Prediction System (LDAPS)** used in South Korea. 

During the turbulent summer monsoon season (*Changma*), the complex mountainous basin of Seoul induces systematic forecasting errors. Our objective is to post-process LDAPS outputs, correcting the structural bias for both Maximum (Tmax) and Minimum (Tmin) temperatures by integrating atmospheric physics with advanced statistical modeling.

## 🗂️ Repository Structure
The project is structured chronologically, reflecting our analytical pipeline:

* **`01_Project_Overview/`** - High-level goals, methodology, and dual-track architecture.
* **`02_Dataset_and_Context/`** - Data dictionary, Korean morphology, and literature review (Cho et al., 2020).
* **`03_EDA_Hypothesis_Testing/`** - Preliminary inferential statistics proving the existence of the systematic bias.
* **`04_Tmax_Model/`** - Modeling track for daytime peak heat predictions.
* **`05_Tmin_Linear_Model/`** - Baseline multiple linear regression for nighttime cooling.
* **`06_Tmin_NonLinear_Model/`** - Advanced 3D topographic modeling using full third-degree interacting polynomials.
* **`07_Temporal_Analysis_Lags/`** - Autocorrelation studies and the implementation of Autoregressive (AR) memory.
* **`08_Conclusions_and_Results/`** - Final performance synthesis and physical interpretations.

## 🔬 Methodology
We refused to treat this as a pure "black-box" machine learning problem. Every feature engineered has a strict physical justification:
1. **Parsimony vs. Precision:** We utilize Stepwise Forward Selection (AIC) and the Adjusted R-squared "Elbow Method" to penalize algebraic overfitting.
2. **Thermal Inertia:** Integration of autoregressive lags and temperature derivatives (`TrendTMAX`, `TrendTMIN`) to simulate urban heat retention.
3. **Geometrical Non-Linearity:** Upgrading from a 2D "tilted plane" linear model to fully interacting 3D cubic polynomials (mapping the interaction of all degrees up to the third: `Elevation` and `Slope`) to mathematically simulate cold air pooling in physical valleys.
4. **Out-of-Sample Validation:** The models are trained on 2013-2016 data and strictly backtested on unseen 2017 data to evaluate real-world RMSE and Mean Bias Error (MBE) reduction.

## 📚 Reference:
The reference PDF is available in the Reference Section of this Github repository. For a broader understanding, here is the original link to the study:
https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2019EA000740

---

## 📊 Final Results & Conclusions

The application of our analytical pipeline successfully dismantled the systematic errors of the global LDAPS model, employing a "dual-track" approach to address both daytime (Tmax) and nighttime (Tmin) dynamics.

### 🔴 Tmax Correction: Linear Model (Baseline)
Daytime heating suffers from structural inertia and radiative dynamics that the LDAPS model struggles to capture. We developed a multiple linear regression model, optimized via a *Forward Selection* algorithm coupled with the "Elbow Rule" on the Adjusted R-squared to prevent algebraic overfitting (electing Model 5 as the optimal *cut-off*).

* **Physical Meaning:** The model captures the *Stationary Memory* of the error (using Lags at 1, 3, and 5 days to "remember" prolonged heatwaves) alongside *Radiative and Atmospheric Dynamics* (specifically cloud cover and minimum relative humidity, which are heavily correlated with afternoon heating capacity).
* **Backtest Metrics (2017 Test Set):**
  * **RMSE Reduction:** Variance improved by **7.19%**, with out-of-sample RMSE dropping from 1.8696 °C to **1.7351 °C**.
  * **BIAS Correction:** The chronic underestimation of daytime peaks by LDAPS was balanced out to +0.2531 °C, eradicating **27.93%** of the global model's structural defect.

### 🔵 Tmin Correction: Linear Model (Baseline)
For nighttime cooling, we applied the same rigorous parsimonious selection (AIC). Model 5 emerged as optimal once again, though based on completely different physical domains than the daytime model: nocturnal *Stationary Memory*, *Energy Exchange* (Latent heat flux via evaporative dissipation during the monsoon), and *Linear Orography* (Elevation and Slope driving katabatic winds).

* **Backtest Metrics (2017 Test Set):**
  * **RMSE Reduction:** A remarkable **23.54%** improvement in variance against LDAPS (RMSE fell from 1.2310 °C to **0.9413 °C**).
  * **BIAS Eradication:** The crown jewel of the linear model. The chronic nighttime overestimation (-0.6302 °C) was crushed to a mere **-0.0366 °C**. This effectively **corrected 94.20% of the global bias**, perfectly centering the average prediction target.

### 🟣 Tmin Correction: Non-Linear Topographical Model (Advanced)
While the linear model successfully zeroed out the mean bias, it possessed a physical limitation: it treated the Korean mountains as "flat inclined planes" (2D orography), completely ignoring the true "U" and "V" shaped concavity of Seoul's valleys where cold air pools and creates strong thermal inversions at night. 
To overcome this limitation, we introduced interacting third-degree polynomials between Elevation and Slope. This provided the algorithm with the complex geometric degrees of freedom needed to map the micro-valleys in 3D and accurately track these isolated "cold air pockets".

* **Backtest Metrics (2017 Test Set):**
  * **Explained Variance:** Despite severe algebraic penalties, the in-sample Adjusted R-squared jumped from 24.9% to **31.03%**, mathematically proving the real-world impact of the 3D topography and decisively outperforming the linear model.
  * **RMSE Improvement:** The root mean square error was driven down to **0.8966 °C**, achieving an overall **27.17%** improvement compared to the baseline LDAPS error.
  * **Neutral BIAS:** The systematic error remained completely annihilated at **94.23%** (-0.0364 °C).

**🏆 Tmin Synthesis (Linear vs. Non-Linear):** If the Linear model proved to be an excellent *"Marksman"*—centering the overall city-wide aim by zeroing the bias—the Non-Linear Cubic model revealed itself as a true *"Sniper"*. It drastically reduced the dispersion of errors around zero, proving essential for hyper-localized forecasting within complex valley formations.

---
*Project developed for the Data Analysis and Modeling course, Mathematical Engineering, Politecnico di Milano.*
