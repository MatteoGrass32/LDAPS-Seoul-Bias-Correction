```python
import os

f_md = "matteograss32/ldaps-seoul-bias-correction/LDAPS-Seoul-Bias-Correction-5f796e706037465e7646ecc427d6edefd9861884/Analysis/07_Tmin_NonLinear_Model/07_Tmin_NonLinear_Model.md"
f_r = "matteograss32/ldaps-seoul-bias-correction/LDAPS-Seoul-Bias-Correction-5f796e706037465e7646ecc427d6edefd9861884/Analysis/07_Tmin_NonLinear_Model/07_Tmin_NonLinear_Model.R"

if os.path.exists(f_md):
    with open(f_md, 'r') as file:
        print("--- MD ---")
        print(file.read()[:2000])

if os.path.exists(f_r):
    with open(f_r, 'r') as file:
        content = file.read()
        print("\n--- R Script (poly) ---")
        # search for poly or ^3
        lines = content.split('\n')
        for line in lines:
            if 'poly' in line or '^' in line or '*' in line:
                if 'lm(' in line or 'model' in line:
                    print(line.strip())



```

```text
--- MD ---
# Section 7: Advanced Non-Linear Topographic Modeling (Tmin)

**Objective:**
To build upon the linear baseline by introducing interacting cubic polynomials (`Elevation³ * Slope³`), enabling the model to transition from a flat 2D projection to a fully 3D mathematical mapping of Seoul's micro-valleys.

**Physical/Theoretical Meaning:**
While the linear model effectively zeroed the mean bias across the entire city, it inherently treats mountains as infinite "flat inclined planes." This contradicts micro-meteorology: during clear nights, dense cold air flows down mountain slopes and accumulates in concave "U-shaped" or "V-shaped" valleys, creating thermal inversions. 
By multiplying altitude cubed by slope cubed, we grant the algorithm the geometric degrees of freedom (S-curves) required to physically map these "bowls" and track the isolated cold air pockets. 
We validate this complexity through the **Adjusted R-squared Elbow Method** and a strict Out-of-Sample **Battle Royale** to rule out algebraic overfitting.

**Key Results (Metrics extracted from Model 6 Backtest 2017):**
* **In-Sample Optimization:** The Adjusted R-squared skyrocketed from ~24.9% (Linear) to **31.035%** (Model 6: Cubic Interaction). This doubling of explained variance, despite the heavy algebraic penalty of the Adjusted metric, confirms the physical reality of the 3D valleys.
* **Variance Reduction (RMSE Battle Royale):** The Non-Linear model outperformed the Linear one on unseen data. The RMSE dropped from 1.2310 °C (LDAPS baseline) to **0.8966 °C**, achieving a **27.17% improvement** in overall accuracy (vs. 23.54% of the linear model).
* **Systematic Error Eradication (BIAS):** The mean bias remained perfectly neutralized, improving by **94.23%** (from -0.6302 °C to just -0.0364 °C).
* **Linear vs Non-Linear Synthesis:** The Linear model is a "Marksman" (centers the average aim), while the Cubic model is a "Sniper" (drastically reduces the dispersion of errors around the zero mark, essential fo

--- R Script (poly) ---
cat(sprintf("1. Baseline Linear          | R2_Adj: %6.3f%%\n", summary(model_nl_1_linear)$adj.r.squared * 100))
cat(sprintf("2. Linear Interaction       | R2_Adj: %6.3f%%\n", summary(model_nl_2_linear_interaction)$adj.r.squared * 100))
cat(sprintf("3. Baseline Quadratic       | R2_Adj: %6.3f%%\n", summary(model_nl_3_quadratic)$adj.r.squared * 100))
cat(sprintf("4. Baseline Cubic           | R2_Adj: %6.3f%%\n", summary(model_nl_4_cubic)$adj.r.squared * 100))
cat(sprintf("5. Quadratic Interaction    | R2_Adj: %6.3f%%\n", summary(model_nl_5_quadratic_interaction)$adj.r.squared * 100))
cat(sprintf("6. Cubic Interaction        | R2_Adj: %6.3f%%\n", summary(model_nl_6_cubic_interaction)$adj.r.squared * 100))
cat(sprintf("7. Cubic + AR Interaction   | R2_Adj: %6.3f%%\n", summary(model_nl_7_cubic_interaction_ar)$adj.r.squared * 100))
# In interacting polynomial models (x * x^2 * x^3), the VIF will mathematically


```

Ottime osservazioni!

Rispondo subito alla tua **seconda domanda**: l'informazione `Elevation³ * Pendenza³` l'avevo presa testualmente dal tuo file `07_Tmin_NonLinear_Model.md`. Nelle prime righe di quel file, sotto la sezione *Objective*, avevi infatti scritto: *"introducing interacting cubic polynomials (`Elevation³ * Slope³`)"*.
Tuttavia, **hai assolutamente ragione dal punto di vista matematico**: quando in R crei un'interazione tra polinomi di terzo grado (ad esempio usando la funzione `poly(..., 3)`), il modello sviluppa l'intera espansione polinomiale, ovvero `(Elevation³ + Elevation² + Elevation) * (Slope³ + Slope² + Slope)`, e non solo il termine di grado massimo. È un'osservazione molto precisa e corretta che merita di essere esplicitata per mostrare la reale complessità geometrica (le "S-curves" complete) del vostro modello.

Ho aggiornato e corretto questa informazione nel README. Se vuoi, nel tuo file `07_Tmin_NonLinear_Model.md` potresti aggiornare la formula scritta lì per renderla coerente con questa spiegazione.

Ecco il tuo **README.md** tradotto in inglese e aggiornato con le tue richieste:

---

```markdown
# 🌤️ LDAPS Seoul Thermal Bias Correction
**Statistical and machine learning pipeline to correct the thermal bias of the LDAPS weather forecasting model in Seoul. Developed for the Mathematical Engineering program at Politecnico di Milano.**

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
* **`04_Temporal_Analysis_Lags/`** - Autocorrelation studies and the implementation of Autoregressive (AR) memory.
* **`05_Tmax_Model/`** - Modeling track for daytime peak heat predictions.
* **`06_Tmin_Linear_Model/`** - Baseline multiple linear regression for nighttime cooling.
* **`07_Tmin_NonLinear_Model/`** - Advanced 3D topographic modeling using full third-degree interacting polynomials.
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
  * **BIAS Correction:** The chronic underestimation of daytime peaks by LDAPS (initial MBE of -0.3513 °C) was balanced out to +0.2531 °C, eradicating **27.93%** of the global model's structural defect.

### 🔵 Tmin Correction: Linear Model (Baseline)
For nighttime cooling, we applied the same rigorous parsimonious selection (AIC). Model 5 emerged as optimal once again, though based on completely different physical domains than the daytime model: nocturnal *Stationary Memory*, *Energy Exchange* (Latent heat flux via evaporative dissipation during the monsoon), and *Linear Orography* (Elevation and Slope driving katabatic winds).

* **Backtest Metrics (2017 Test Set):**
  * **RMSE Reduction:** A remarkable **23.54%** improvement in variance against LDAPS (RMSE fell from 1.2310 °C to **0.9413 °C**).
  * **BIAS Eradication:** The crown jewel of the linear model. The chronic nighttime overestimation (-0.6302 °C) was crushed to a mere **-0.0366 °C**. This effectively **corrected 94.20% of the global bias**, perfectly centering the average prediction target.

### 🟣 Tmin Correction: Non-Linear Topographical Model (Advanced)
While the linear model successfully zeroed out the mean bias, it possessed a physical limitation: it treated the Korean mountains as "flat inclined planes" (2D orography), completely ignoring the true "U" and "V" shaped concavity of Seoul's valleys where cold air pools and creates strong thermal inversions at night. 
To overcome this limitation, we introduced **interacting third-degree polynomials** — utilizing the full polynomial expansion `(Elevation³ + Elevation² + Elevation) * (Slope³ + Slope² + Slope)`. This provided the algorithm with the complex geometric degrees of freedom needed to map the micro-valleys in 3D and accurately track these isolated "cold air pockets".

* **Battle Royale Backtest Metrics (2017 Test Set):**
  * **Explained Variance:** Despite severe algebraic penalties, the in-sample Adjusted R-squared jumped from 24.9% to **31.03%**, mathematically proving the real-world impact of the 3D topography and decisively outperforming the linear model.
  * **RMSE Improvement:** The root mean square error was driven down to **0.8966 °C**, achieving an overall **27.17%** improvement compared to the baseline LDAPS error.
  * **Neutral BIAS:** The systematic error remained completely annihilated at **94.23%** (-0.0364 °C).

**🏆 Tmin Synthesis (Linear vs. Non-Linear):** If the Linear model proved to be an excellent *"Marksman"*—centering the overall city-wide aim by zeroing the bias—the Non-Linear Cubic model revealed itself as a true *"Sniper"*. It drastically reduced the dispersion of errors around zero, proving essential for hyper-localized forecasting within complex valley formations.

---

*Project developed for the "Models And Methods For Statistical Inference" course, Mathematical Engineering, Politecnico di Milano.*

```