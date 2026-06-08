# Section 2: Dataset, Climatology & LDAPS Framework

**Objective:**
To define the geographical and meteorological constraints of the dataset, outline the structural limits of the LDAPS model, and establish the scientific literature baseline.

**Physical/Theoretical Context:**
The dataset covers the summer seasons (2013-2017) across 25 meteorological stations in Seoul. To understand the bias, we must understand the environment:
* **Korea's Morphology:** Seoul is a massive urban heat island nestled in a complex basin, surrounded by steep mountains and bisected by the Han River. This topography creates localized micro-climates (e.g., cold air pooling in valleys).
* **The Changma Monsoon:** The Korean summer is dominated by the East Asian Monsoon ("Changma"). It is a highly turbulent season characterized by extreme humidity, heavy rainfall, and sudden clear skies leading to intense radiative cooling or heating.
* **The LDAPS Model:** The *Local Data Assimilation and Prediction System* is the operational NWP model used by the Korean Meteorological Administration (KMA). It operates on a 1.5 km spatial resolution grid. While highly advanced, this grid size is still too coarse to "see" specific urban canyons or narrow valleys, leading to systematic forecasting errors.

**Literature & Baseline:**
Our approach is inspired by and builds upon the foundational paper: *"Comparative Assessment of Various Machine Learning Based Bias Correction Methods for LDAPS"* (Cho et al., Earth and Space Science, 2020). The paper highlights that machine learning can successfully correct NWP models by capturing non-linear geographical relationships that fluid dynamics equations simplify.

**Tmax vs. Tmin Asymmetry:**
* **Tmax (Daytime):** Driven heavily by incoming solar radiation, cloud cover, and the urban heat island effect (concrete retaining heat). Highly volatile.
* **Tmin (Nighttime):** Governed by latent heat flux (evaporation from saturated summer soils) and topographic thermal inversions (dense cold air sliding down mountain slopes into valleys).
