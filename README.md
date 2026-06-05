# 🌤️ LDAPS Seoul Thermal Bias Correction
**Statistical and machine learning pipeline to correct the thermal bias of the LDAPS weather forecasting model in Seoul. Developed for the Mathematical Engineering program at Politecnico di Milano.**

## 📖 Project Overview
Numerical Weather Prediction (NWP) models are the backbone of modern meteorology, but they struggle with micro-scale topographical features. This project focuses on the **Local Data Assimilation and Prediction System (LDAPS)** used in South Korea. 

During the turbulent summer monsoon season (*Changma*), the complex mountainous basin of Seoul induces systematic forecasting errors. Our objective is to post-process LDAPS outputs, correcting the structural bias for both Maximum (Tmax) and Minimum (Tmin) temperatures by integrating atmospheric physics with advanced statistical modeling.

## 🗂️ Repository Structure
The project is structured chronologically, reflecting our analytical pipeline:

* **`01_Project_Overview/`** - High-level goals, methodology, and dual-track architecture.
* **`02_Dataset_and_Context/`** - Data dictionary, Korean morphology, and literature review (Cho et al., 2020).
* **`03_EDA_Hypothesis_Testing/`** - Preliminary inferential statistics proving the existence of the systematic bias.
* **`04_Temporal_Analysis_Lags/`** - Autocorrelation studies and the implementation of Autoregressive (AR) memory.
* **`05_Tmax_Model/`** - Modeling track for daytime peak heat predictions.
* **`06_Tmin_Linear_Model/`** - Baseline multiple linear regression for nighttime cooling.
* **`07_Tmin_NonLinear_Model/`** - Advanced 3D topographic modeling using interacting cubic polynomials.
* **`08_Conclusions_and_Results/`** - Final performance synthesis and physical interpretations.

## 🔬 Methodology
We refused to treat this as a pure "black-box" machine learning problem. Every feature engineered has a strict physical justification:
1. **Parsimony vs. Precision:** We utilize Stepwise Forward Selection (AIC) and the Adjusted R-squared "Elbow Method" to penalize algebraic overfitting.
2. **Thermal Inertia:** Integration of autoregressive lags and temperature derivatives (`TrendTMAX`, `TrendTMIN`) to simulate urban heat retention.
3. **Geometrical Non-Linearity:** Upgrading from a 2D "tilted plane" linear model to 3D interacting cubic polynomials (`Elevation³ * Slope³`) to mathematically simulate cold air pooling in physical valleys.
4. **Out-of-Sample Validation:** The models are trained on 2013-2016 data and strictly backtested on unseen 2017 data to evaluate real-world RMSE and Mean Bias Error (MBE) reduction.

## 📊 Final Results
*(This section is currently being updated as the final models are synthesized. Stay tuned for the final Battle Royale metrics between LDAPS, Linear, and Non-Linear approaches).*

---
*Project developed for the Data Analysis and Modeling course, Mathematical Engineering, Politecnico di Milano.*