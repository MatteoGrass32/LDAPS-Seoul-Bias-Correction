# 07. Temporal and Spectral Error Decomposition

### Objective
Decompose LDAPS thermal forecast errors in Seoul into persistent low-frequency dynamics and high-frequency stochastic residuals using a phase-aligned FIR filter.

### Physical & Theoretical Meaning
* **Atmospheric Memory**: Forecast errors ($e_t = T_{obs} - T_{fct}$) exhibit temporal persistence driven by multi-day synoptic weather systems.
* **Spectral Splitting**: A 10th-order windowed-sinc FIR filter isolates slow errors from fast fluctuations at a cutoff $f_c = 0.2$ cycles/day ($\ge 5$ days).
* **Group-Delay Alignment**: Moving-average filters delay signals. Shifting outputs back by $K = M/2 = 5$ days maintains exact physical and temporal alignment: $e_{centered} = y_{LP} + y_{HP}$.

### Key Results & Metrics
* **Spectral Footprint**: **~46%** of baseline error power is concentrated in the low-frequency band ($f \le 0.2$), proving long-memory systemic inflation.
* **Dynamic Shift**: Low-pass filtering captures the persistent memory structure perfectly, leaving the high-pass component with zero long-lag correlation.
* **Residual Anti-Persistence**: The high-pass residual displays an intense negative lag-1 bounce ($	ext{ACF} \approx -0.5$), highlighting rapid error-correction loops.
* **Ljung-Box Diagnostic**: The share of stations showing white-noise behavior drops to **0%** post-filtering, indicating structured high-frequency anti-persistence rather than pure random noise.