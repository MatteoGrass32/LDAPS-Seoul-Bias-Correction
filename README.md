# LDAPS Seoul Thermal Bias Correction

Statistical post-processing of the Local Data Assimilation and Prediction System (LDAPS), the numerical weather prediction model operated over South Korea, to correct its systematic temperature bias over Seoul.

Models are fitted on 2013-2016 and evaluated on 2017, held out entirely. On minimum temperatures the correction removes 94% of the systematic bias and reduces out-of-sample RMSE by 27%. On maximum temperatures the gain is smaller.

**Authors:** Matteo Grassini, Alice Rossato, Andrea Santimaria
Developed for the Data Analysis and Modeling course, Mathematical Engineering, Politecnico di Milano.

## Problem

Numerical weather prediction models resolve the atmosphere on a grid too coarse to capture micro-scale terrain. Seoul sits in a mountainous basin, and during the summer monsoon season (*Changma*) the resulting forecast errors are not random: LDAPS underestimates daytime peaks and overestimates nighttime lows in a way that persists across days and locations.

A bias that systematic can be modelled. The goal here is not to rebuild the forecast, but to learn the structure of its error from past data and subtract it.

## Results

Test set is 2017, never seen during fitting. Temperatures in °C.

| Target | Model | RMSE LDAPS | RMSE corrected | RMSE change | Bias LDAPS | Bias corrected | Bias removed |
|---|---|---|---|---|---|---|---|
| Tmax | Linear | 1.8696 | 1.7351 | -7.19% | — | +0.2531 | 27.93% |
| Tmin | Linear | 1.2310 | 0.9413 | -23.54% | -0.6302 | -0.0366 | 94.20% |
| Tmin | Cubic topographic | 1.2310 | 0.8966 | -27.17% | -0.6302 | -0.0364 | 94.23% |

The two targets behave differently, and the difference is physical rather than statistical.

**Nighttime minima** are driven by radiative cooling and cold air drainage, both of which depend on terrain in a stable and learnable way. Here the correction works well. The linear model alone brings the mean bias from -0.6302 °C to -0.0366 °C, centring the forecast almost exactly.

**Daytime maxima** depend on convection and cloud dynamics that are genuinely harder to predict from the available covariates. A 7% RMSE reduction is a real but modest improvement, and roughly a quarter of the bias survives the correction. We report it as it came out.

### Linear vs. cubic on Tmin

The linear model zeroes the average bias but treats the terrain as a tilted plane. It cannot represent the concave valleys where cold air pools and thermal inversions form, so its errors stay large at individual stations even though they cancel across the city.

Adding fully interacting third-degree polynomials in elevation and slope gives the model the freedom to represent those basins. In-sample adjusted R² rises from 24.9% to 31.03%, and out-of-sample RMSE falls further to 0.8966 °C. The mean bias is unchanged, since it was already near zero.

The summary: the linear model centres the aim, the cubic model tightens the grouping. For city-wide averages the first is sufficient; for station-level forecasting in the valleys the second is not.

## Method

Every feature has a physical justification rather than being selected by search alone.

**Model selection.** Stepwise forward selection on AIC, with the choice of cut-off confirmed by the elbow in adjusted R². Model 5 was retained for both targets, though built from different variables in each case.

**Thermal inertia.** Autoregressive lags at 1, 3 and 5 days, plus temperature trend terms (`TrendTMAX`, `TrendTMIN`), let the model carry the memory of prolonged heatwaves and cooling spells.

**Terrain.** Elevation and slope enter linearly in the baseline, and as fully interacting third-degree polynomials in the advanced Tmin model.

**Retained predictors.** The Tmax model keeps cloud cover and minimum relative humidity, both tied to afternoon heating capacity. The Tmin model instead keeps latent heat flux, which reflects evaporative dissipation during the monsoon, and the orographic terms driving katabatic winds.

**Validation.** Fitting uses 2013-2016 only. All figures above are computed on 2017, and both RMSE and mean bias error are reported, since a model can centre the bias without reducing dispersion, or the reverse.

## Repository structure

The directories follow the order of the analysis.

* `01_Project_Overview/` - goals, methodology, dual-track architecture
* `02_Dataset_and_Context/` - data dictionary, Korean morphology, literature review (Cho et al., 2020)
* `03_EDA_Hypothesis_Testing/` - inferential statistics establishing that the bias is systematic
* `04_Tmax_Model/` - daytime maxima
* `05_Tmin_Linear_Model/` - nighttime minima, linear baseline
* `06_Tmin_NonLinear_Model/` - nighttime minima, cubic topographic model
* `07_Temporal_Analysis_Lags/` - autocorrelation and autoregressive terms
* `08_Conclusions_and_Results/` - final comparison and physical interpretation

Written in R.

## Reference

Cho, D., Yoo, C., Im, J., & Cha, D.-H. (2020). *Comparative Assessment of Various Machine Learning-Based Bias Correction Methods for Numerical Weather Prediction Model Forecasts of Extreme Air Temperatures in Urban Areas*. Earth and Space Science, 7(4). https://agupubs.onlinelibrary.wiley.com/doi/10.1029/2019EA000740

The PDF is included in `Reference/`.
