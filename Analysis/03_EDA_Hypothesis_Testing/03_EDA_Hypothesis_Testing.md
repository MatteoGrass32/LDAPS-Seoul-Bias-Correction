# Section 3: Exploratory Data Analysis & Hypothesis Testing

**Objective:**
To rigorously verify the integrity of the dataset, statistically prove the existence of systematic thermal biases in the LDAPS model, and identify the physical anomalies (e.g., topographical elevation and diurnal temperature ranges) driving these forecasting errors.

**Physical/Theoretical Meaning:**
Before building complex correction algorithms, we must map the anatomy of the error (defined as `Observed - Predicted`). 
Meteorological variables are physically coupled. The LDAPS model operates on a coarse grid that inherently "smooths out" extreme urban topography. This creates distinct physical failures:
* **Daytime (Tmax):** Driven by incoming solar radiation and urban heat absorption. If the model misses the urban heat island effect, we expect an error $> 0$ (underestimation).
* **Nighttime (Tmin):** Driven by radiational cooling and katabatic winds. If the model misses cold air pooling in valleys, we expect an error $< 0$ (overestimation).
* **Diurnal Temperature Range (DTR):** Calculated as `Tmax - Tmin`. If LDAPS misses both extremes, it will predict an artificially "flattened" day-night curve.
* **Topographical Smoothing (DEM):** Because the global model averages out the altitude, forecasting accuracy should visibly degrade as elevation changes (valleys vs. peaks).

**Key Results (Metrics):**
* **Data Integrity:** The dataset is perfectly clean. Out of 7,588 observations across 25 stations, there are **0 missing values (NAs)**, ensuring robust inferential modeling.
* **Tmax Systematic Bias:** The one-sided hypothesis tests yield p-values computationally indistinguishable from zero ($< 10^{-199}$). The mean error is **+0.6214 °C** (95% CI: **[+0.5822, +0.6606] °C**), providing strict statistical evidence of a systematic **underestimation** of daytime heat.
* **Tmin Systematic Bias:** Similarly, the tests confirm a mean error of **-0.6010 °C** (95% CI: **[-0.6270, -0.5749] °C**). The narrow confidence interval confirms the model systematically **overestimates** nighttime cooling with high precision.
* **DTR Flattening:** The Diurnal Temperature Range analysis reveals a mean error of **+1.2224 °C** (with peaks up to +9.3 °C). This proves that the global model is structurally "blind" to the true thermal volatility of the Seoul basin, predicting days that are too cold and nights that are too warm.
* **The Altitude Penalty:** Loess smoothing and categorical boxplots demonstrate a clear correlation between the Absolute Error and the Digital Elevation Model (DEM). The model's physics fail to scale accurately with the rugged Korean topography.

