# ==============================================================================
# METEOROLOGICAL FORECAST ERROR ANALYSIS
# Dynamic and Spectral Decomposition of Tmin / Tmax Forecast Errors
# ==============================================================================
#
# Repository-ready R script
# ------------------------------------------------------------------------------
# Author: <insert author name>
# Project: Statistical analysis of meteorological forecast error time series
# Main output: reproducible station-level and aggregate diagnostics for Tmin/Tmax
#
# ------------------------------------------------------------------------------
# 1. Statistical and modelling convention
# ------------------------------------------------------------------------------
#
# Throughout the script, the forecast error is defined as
#
#     error(t, s) = observed_temperature(t, s) - forecast_temperature(t, s),
#
# where:
#     t = daily time index,
#     s = meteorological station.
#
# Consequently:
#     error > 0  means that the numerical weather prediction system
#                underestimates the observed temperature;
#     error < 0  means that the numerical weather prediction system
#                overestimates the observed temperature.
#
# This sign convention is kept explicit because it determines the physical
# interpretation of all static-bias, dynamic-memory and spectral diagnostics.
#
# ------------------------------------------------------------------------------
# 2. Scientific objective
# ------------------------------------------------------------------------------
#
# The pipeline is designed to investigate whether the forecast error contains
# a structured, temporally persistent component that cannot be interpreted as
# purely high-frequency stochastic noise.
#
# Operationally, the analysis aims to separate:
#
#     (i)   a station-specific static bias,
#           interpreted as a time-independent systematic displacement;
#
#     (ii)  a low-frequency dynamic component,
#           interpreted as the temporally persistent part of the centered error;
#
#     (iii) a high-frequency residual component,
#           interpreted as the complementary short-memory fluctuation after
#           removal of the low-frequency part.
#
# The main diagnostic logic is therefore:
#
#     persistent temporal memory  -> visible in the ACF;
#     low-frequency concentration -> visible in the PSD;
#     filter-based decomposition  -> explicit low-pass/high-pass split;
#     residual whiteness check    -> Ljung-Box tests after filtering.
#
# ------------------------------------------------------------------------------
# 3. Methodological structure of the pipeline
# ------------------------------------------------------------------------------
#
# The script performs the following steps:
#
#   1. Load and clean the original Excel dataset.
#   2. Reconstruct/validate Tmin and Tmax forecast errors using the convention
#      observed minus forecast.
#   3. Build regular station-date time series for both Tmin and Tmax.
#   4. Estimate the baseline autocorrelation function (ACF) station by station
#      and aggregate the results across stations.
#   5. Estimate the baseline power spectral density (PSD) and quantify how much
#      spectral energy lies below/above a critical frequency.
#   6. Design a finite impulse response (FIR) windowed-sinc low-pass filter.
#   7. Construct the complementary high-pass filter in a group-delay-consistent
#      way.
#   8. Decompose the centered error into low-pass and high-pass components.
#   9. Recompute ACF, PSD, spectral features and Ljung-Box diagnostics on the
#      decomposed components.
#  10. Export all intermediate and final objects to CSV/RDS files for inspection,
#      reproducibility and downstream reporting.
#
# ------------------------------------------------------------------------------
# 4. Critical signal-processing detail: group-delay correction
# ------------------------------------------------------------------------------
#
# The FIR low-pass filter used here is causal and has linear phase. If the filter
# order is M, with M even, the group delay is
#
#     K = M / 2  samples.
#
# Therefore, the causal low-pass output
#
#     y_LP[t] = sum_{ell = 0}^{M} h[ell] x[t - ell]
#
# is not naturally aligned with x[t], but with the centered time index t - K.
#
# For this reason, the high-pass residual is NOT computed as x[t] - y_LP[t].
# Instead, the complementary high-pass filter is defined as
#
#     g[ell] = delta[ell, K] - h[ell],
#
# so that
#
#     y_HP[t] = sum_{ell = 0}^{M} g[ell] x[t - ell]
#             = x[t - K] - y_LP[t].
#
# After shifting the causal outputs back by K days, the following identity holds
# on the valid aligned interval:
#
#     centered_error_aligned = lowpass_component + highpass_residual.
#
# The script explicitly exports an alignment-identity diagnostic to verify that
# the numerical decomposition is internally consistent.
#
# ------------------------------------------------------------------------------
# 5. Reproducibility notes
# ------------------------------------------------------------------------------
#
# - The script is written as a single executable analysis pipeline.
# - All relevant tuning parameters are collected in Section 0.
# - The output directory is created automatically.
# - Missing internal values in time series are linearly interpolated before ACF,
#   PSD and filtering operations; leading/trailing gaps are filled by nearest
#   available boundary values. This is a pragmatic preprocessing convention for
#   regular daily time-series diagnostics and should be reported explicitly.
# - The script stops early if required packages, required columns or the selected
#   Excel sheet are missing.
#
# ==============================================================================


# ============================================================
# 0. USER PARAMETERS
# ============================================================

# This block centralizes all user-editable analysis parameters.
# Keeping these parameters in a single location improves reproducibility and
# makes sensitivity analyses easier: the statistical logic of the pipeline can
# be rerun after changing lags, PSD settings, filter order or output options
# without modifying the computational core.

# If TRUE, remove all objects from the active R workspace except the parameters
# defined in this block. This is useful in interactive RStudio sessions because
# it prevents stale objects from previous runs from contaminating the analysis.
# In automated scripts or notebooks, setting this to FALSE may be preferable.
RESET_ENV <- TRUE

# Path to the Excel workbook containing the meteorological dataset.
# For a public GitHub repository, consider replacing this local path with a
# relative path such as "data/CoreaForecasting2013-2017.xlsx".
file_path <- "~/Desktop/CoreaForecasting2013-2017.xlsx"

# Excel sheet containing the cleaned data with observed/forecast temperatures
# and, possibly, precomputed error columns.
sheet_name <- "DatiConColonneErrori"

# Root folder where all tables, figures, diagnostics and serialized objects are
# written. The script creates the complete output tree automatically.
output_dir <- "output_dynamic_spectral_error_pipeline"

# Maximum lag, in days, used in ACF diagnostics. With daily sampling, max_lag = 40
# means that serial dependence is inspected up to approximately forty days.
max_lag <- 40

# Whether to include lag zero in ACF tables and plots. Lag zero is always equal
# to one by definition, so it is excluded by default for clearer diagnostics.
include_lag0 <- FALSE

# Sampling interval used by the PSD estimator. The dataset is daily, therefore
# the natural sampling interval is one day and the Nyquist frequency is
# 0.5 cycles/day.
PSD_SAMPLING_INTERVAL_DAYS <- 1

# Spectral taper used before the FFT periodogram. The Hann window reduces
# spectral leakage relative to the rectangular window.
PSD_WINDOW <- "hann"           # alternatives: "rectangular", "hann"

# Baseline PSD preprocessing. Removing the mean focuses the spectrum on dynamic
# fluctuations around the average error. Optional linear detrending can be
# enabled if the error series exhibits a long-term drift.
PSD_REMOVE_MEAN_BASELINE <- TRUE
PSD_REMOVE_LINEAR_TREND_BASELINE <- FALSE

# PSD preprocessing after decomposition. These are set independently because the
# low-pass/high-pass components are already centered by construction.
PSD_REMOVE_MEAN_DECOMPOSITION <- FALSE
PSD_REMOVE_LINEAR_TREND_DECOMPOSITION <- FALSE

# Critical frequency used to separate low-frequency from high-frequency energy.
# At daily sampling, f_c = 0.20 cycles/day corresponds to a period of 5 days.
# Frequencies below this threshold represent slower, more persistent variations.
PSD_CRITICAL_FREQUENCY <- 0.20 # cycles/day
PSD_CRITICAL_PERIOD_DAYS <- 1 / PSD_CRITICAL_FREQUENCY

# If TRUE, the zero-frequency bin is ignored when identifying the dominant
# frequency, avoiding a trivial dominance of the mean/DC component.
PSD_DOMINANT_EXCLUDE_ZERO <- TRUE

# Small numerical tolerance used to avoid divisions by zero in spectral ratios.
PSD_EPS <- 1e-12

# FIR low-pass filter order. The number of taps is M + 1. This pipeline requires
# an even order so that the linear-phase group delay K = M/2 is an integer number
# of daily samples.
FIR_ORDER_M <- 10

# The FIR cutoff is set equal to the critical PSD frequency so that spectral
# feature extraction and filter-based decomposition use the same low/high split.
FIR_CUTOFF_FREQUENCY <- PSD_CRITICAL_FREQUENCY

# Window used in the windowed-sinc FIR design. The Hamming window provides a
# practical compromise between transition-band width and side-lobe attenuation.
FIR_WINDOW <- "hamming"        # alternatives: "rectangular", "hann", "hamming"

# Normalize the low-pass filter so that the DC gain is exactly one. This ensures
# that slowly varying components are not artificially rescaled.
FIR_NORMALIZE_DC_GAIN <- TRUE

# Ljung-Box diagnostic lags. These are interpreted as short/medium memory checks
# at 5, 10 and 20 days.
LJUNG_BOX_LAGS <- c(5, 10, 20)

# Significance level used in Ljung-Box tests.
LJUNG_BOX_ALPHA <- 0.05

# Number of fitted parameters to subtract in Ljung-Box degrees of freedom.
# Since this script is not fitting an ARMA model before testing, the default is 0.
LJUNG_BOX_FITDF <- 0

# ACF memory summary settings. The threshold defines what "small" autocorrelation
# means, and consecutive_lags prevents declaring memory exhausted after a single
# accidental crossing.
ACF_MEMORY_THRESHOLD <- 0.10
ACF_MEMORY_CONSECUTIVE_LAGS <- 3

# Plot export settings. Individual station-level plots are optional because they
# can produce many files. Aggregate plots are always saved.
SAVE_INDIVIDUAL_STATION_PLOTS <- FALSE
PLOT_WIDTH <- 10
PLOT_HEIGHT <- 7
PLOT_DPI <- 300


# ============================================================
# 1. ENVIRONMENT AND PACKAGES
# ============================================================

# This block initializes the R session, checks the software dependencies and
# loads the required packages. The script deliberately fails with an explicit
# error message if a package is missing, because silent package failures would
# compromise reproducibility in a GitHub repository or on another machine.

if (RESET_ENV) {
  keep_objects <- c(
    "RESET_ENV", "file_path", "sheet_name", "output_dir",
    "max_lag", "include_lag0",
    "PSD_SAMPLING_INTERVAL_DAYS", "PSD_WINDOW",
    "PSD_REMOVE_MEAN_BASELINE", "PSD_REMOVE_LINEAR_TREND_BASELINE",
    "PSD_REMOVE_MEAN_DECOMPOSITION", "PSD_REMOVE_LINEAR_TREND_DECOMPOSITION",
    "PSD_CRITICAL_FREQUENCY", "PSD_CRITICAL_PERIOD_DAYS",
    "PSD_DOMINANT_EXCLUDE_ZERO", "PSD_EPS",
    "FIR_ORDER_M", "FIR_CUTOFF_FREQUENCY", "FIR_WINDOW",
    "FIR_NORMALIZE_DC_GAIN", "LJUNG_BOX_LAGS", "LJUNG_BOX_ALPHA",
    "LJUNG_BOX_FITDF", "ACF_MEMORY_THRESHOLD", "ACF_MEMORY_CONSECUTIVE_LAGS",
    "SAVE_INDIVIDUAL_STATION_PLOTS", "PLOT_WIDTH", "PLOT_HEIGHT", "PLOT_DPI"
  )
  rm(list = ls()[!ls() %in% keep_objects])
  graphics.off()
}

options(scipen = 999)
options(stringsAsFactors = FALSE)

required_packages <- c(
  "readxl", "dplyr", "tidyr", "tibble", "purrr", "stringr",
  "lubridate", "ggplot2", "janitor", "readr", "zoo"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    paste0(
      "Missing packages: ", paste(missing_packages, collapse = ", "),
      ". Install them with install.packages(c(",
      paste(sprintf('"%s"', missing_packages), collapse = ", "),
      ")) and rerun the script."
    )
  )
}

invisible(lapply(required_packages, library, character.only = TRUE))


# ============================================================
# 2. OUTPUT DIRECTORIES
# ============================================================

# This block creates a structured output tree. Each analytical layer has its
# own folder: diagnostics, raw/regularized series, baseline ACF, baseline PSD,
# dynamic-spectral decomposition, filter diagnostics, and Ljung-Box tests.
# A stable folder structure is essential for traceability and downstream
# reporting.

#' Create a directory recursively if it does not already exist.
#'
#' The function is intentionally minimal and silent: repeated executions of the
#' pipeline should not fail simply because the output folders already exist.
make_dir <- function(...) {
  dir.create(file.path(...), recursive = TRUE, showWarnings = FALSE)
}

make_dir(output_dir)
make_dir(output_dir, "diagnostics")
make_dir(output_dir, "series")
make_dir(output_dir, "baseline_acf")
make_dir(output_dir, "baseline_psd")
make_dir(output_dir, "baseline_psd", "station_level")
make_dir(output_dir, "baseline_psd", "aggregated")
make_dir(output_dir, "baseline_psd", "cumulative_energy")
make_dir(output_dir, "baseline_psd", "spectral_features")
make_dir(output_dir, "dynamic_spectral_decomposition")
make_dir(output_dir, "dynamic_spectral_decomposition", "fir_filter")
make_dir(output_dir, "dynamic_spectral_decomposition", "series")
make_dir(output_dir, "dynamic_spectral_decomposition", "acf")
make_dir(output_dir, "dynamic_spectral_decomposition", "psd")
make_dir(output_dir, "dynamic_spectral_decomposition", "spectral_features")
make_dir(output_dir, "dynamic_spectral_decomposition", "ljung_box")
make_dir(output_dir, "dynamic_spectral_decomposition", "plots")


# ============================================================
# 3. GENERAL UTILITY FUNCTIONS
# ============================================================

# The following helper functions implement robust data parsing, safe summary
# statistics and regularization of daily time series. They are intentionally
# separated from the analytical pipeline so that the core workflow remains
# readable and each preprocessing convention is inspectable.

#' Safely parse a vector as numeric.
#'
#' The original Excel dataset may contain numbers encoded as strings, decimal
#' commas, blank cells or spreadsheet error tokens. This function standardizes
#' such entries before numerical conversion, returning NA whenever a value cannot
#' be interpreted as a valid number.
parse_num_safe <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))
  x <- as.character(x)
  x <- stringr::str_squish(x)
  x <- stringr::str_replace_all(x, ",", ".")
  x[x %in% c("", "NA", "NaN", "NULL", "#DIV/0!", "#N/A", "-", "--")] <- NA_character_
  suppressWarnings(as.numeric(x))
}

#' Safely parse dates from heterogeneous Excel/date formats.
#'
#' The function supports Date/POSIX objects, Excel serial dates and common
#' character date formats. Returning Date objects early makes all downstream
#' station-date operations deterministic.
parse_date_safe <- function(x) {
  if (inherits(x, "Date")) return(as.Date(x))
  if (inherits(x, "POSIXt")) return(as.Date(x))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))

  x_chr <- stringr::str_squish(as.character(x))
  x_chr[x_chr %in% c("", "NA", "NaN", "NULL")] <- NA_character_

  out <- suppressWarnings(lubridate::ymd(x_chr))
  if (all(is.na(out))) out <- suppressWarnings(lubridate::dmy(x_chr))
  if (all(is.na(out))) out <- suppressWarnings(lubridate::mdy(x_chr))
  as.Date(out)
}

#' Return the first non-missing entry of a vector.
#'
#' This is useful when metadata or diagnostic quantities are constant within
#' groups and only one representative non-missing value is needed.
first_non_missing <- function(x) {
  y <- x[!is.na(x)]
  if (length(y) == 0) return(NA)
  y[[1]]
}

#' Convert an arbitrary string into a filesystem-safe filename fragment.
#'
#' Station identifiers or labels may contain spaces or special characters. This
#' helper replaces them with underscores to avoid invalid output filenames.
sanitize_filename <- function(x) {
  x <- as.character(x)
  x <- stringr::str_replace_all(x, "[^A-Za-z0-9_\\-]+", "_")
  x <- stringr::str_replace_all(x, "_+", "_")
  x
}

#' Compute a mean while preserving all-missing vectors as NA.
#'
#' Base R returns NaN for mean(..., na.rm = TRUE) when all values are missing.
#' This helper returns NA_real_ instead, which is easier to handle in diagnostics.
safe_mean <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  mean(x, na.rm = TRUE)
}

#' Compute a standard deviation only when at least two observations are available.
#'
#' The standard deviation is undefined for fewer than two non-missing values.
#' Returning NA_real_ avoids misleading zero-variance diagnostics.
safe_sd <- function(x) {
  if (sum(!is.na(x)) < 2) return(NA_real_)
  stats::sd(x, na.rm = TRUE)
}

#' Regularize a numerical time series for ACF, PSD and FIR filtering.
#'
#' ACF, FFT-based PSD estimates and FIR filtering require a regular numerical
#' sequence. Internal missing values are linearly interpolated, while leading and
#' trailing gaps are filled using the nearest available boundary value. This
#' convention avoids changing the length of the daily grid.
prepare_regular_series <- function(x) {
  x <- as.numeric(x)
  if (length(x) == 0) return(x)
  if (all(is.na(x))) return(rep(NA_real_, length(x)))

  # Linear interpolation for internal gaps.
  x_out <- zoo::na.approx(x, na.rm = FALSE)

  # Carry boundary values outward if leading/trailing gaps are present.
  x_out <- zoo::na.locf(x_out, na.rm = FALSE)
  x_out <- zoo::na.locf(x_out, fromLast = TRUE, na.rm = FALSE)
  as.numeric(x_out)
}


# ============================================================
# 4. ACF FUNCTIONS
# ============================================================

# The ACF functions quantify temporal memory in the forecast error. A slowly
# decaying ACF is interpreted as evidence that part of the error is persistent
# across days and therefore cannot be reduced to independent daily noise.

#' Compute the empirical autocorrelation function of a univariate series.
#'
#' The function reports the ACF up to max_lag, together with basic missingness
#' diagnostics and the approximate white-noise confidence bound +/-1.96/sqrt(n).
#' Lag zero can be excluded because it is always equal to one and is usually not
#' informative for memory diagnostics.
compute_acf_vector <- function(x_original, max_lag = 40, include_lag0 = FALSE) {
  x <- prepare_regular_series(x_original)

  n_eff <- sum(!is.na(x_original))
  n_total <- length(x_original)
  n_missing <- sum(is.na(x_original))
  missing_share <- ifelse(n_total > 0, n_missing / n_total, NA_real_)

  if (n_eff < 3 || all(is.na(x)) || isTRUE(stats::sd(x, na.rm = TRUE) == 0)) {
    return(tibble::tibble(
      lag = integer(), acf = numeric(), n_eff = integer(),
      n_total = integer(), n_missing = integer(), missing_share = numeric(),
      conf_limit = numeric()
    ))
  }

  lag_eff <- min(max_lag, n_eff - 1)
  acf_obj <- stats::acf(x, lag.max = lag_eff, plot = FALSE, na.action = na.pass)

  out <- tibble::tibble(
    lag = as.integer(as.numeric(acf_obj$lag)),
    acf = as.numeric(acf_obj$acf),
    n_eff = n_eff,
    n_total = n_total,
    n_missing = n_missing,
    missing_share = missing_share,
    conf_limit = 1.96 / sqrt(n_eff)
  )

  if (!include_lag0) out <- out %>% dplyr::filter(lag > 0)
  out
}

#' Compute the ACF from a station-level data frame.
#'
#' The data frame is sorted by date before extracting the selected value column,
#' ensuring that temporal diagnostics are computed in chronological order.
compute_acf_from_df <- function(df, value_col = "error", max_lag = 40, include_lag0 = FALSE) {
  df <- df %>% dplyr::arrange(date)
  compute_acf_vector(df[[value_col]], max_lag = max_lag, include_lag0 = include_lag0)
}

#' Identify the first lag after which the ACF remains small for consecutive lags.
#'
#' This provides a compact empirical memory-length indicator: the first lag at
#' which |ACF| stays below a selected threshold for a specified number of
#' consecutive lags.
first_lag_run_below <- function(lag, value, threshold = 0.10, consecutive = 3) {
  if (length(lag) == 0 || length(value) == 0 || length(lag) < consecutive) return(NA_integer_)
  ord <- order(lag)
  lag <- lag[ord]
  value <- value[ord]
  ok <- !is.na(value) & abs(value) < threshold
  if (length(ok) < consecutive) return(NA_integer_)
  for (i in seq_len(length(ok) - consecutive + 1)) {
    idx <- i:(i + consecutive - 1)
    if (all(ok[idx])) return(as.integer(lag[i]))
  }
  NA_integer_
}

#' Identify the first lag after which the ACF remains inside its confidence band.
#'
#' This is a statistical analogue of the threshold-based memory metric and uses
#' the approximate white-noise confidence limits attached to the ACF estimates.
first_lag_run_inside_ci <- function(lag, value, limit, consecutive = 3) {
  if (length(lag) == 0 || length(value) == 0 || length(limit) == 0) return(NA_integer_)
  ord <- order(lag)
  lag <- lag[ord]
  value <- value[ord]
  limit <- limit[ord]
  ok <- !is.na(value) & !is.na(limit) & abs(value) <= limit
  if (length(ok) < consecutive) return(NA_integer_)
  for (i in seq_len(length(ok) - consecutive + 1)) {
    idx <- i:(i + consecutive - 1)
    if (all(ok[idx])) return(as.integer(lag[i]))
  }
  NA_integer_
}

#' Return the last lag at which the absolute ACF exceeds a threshold.
#'
#' This is another scalar summary of temporal persistence. Larger values indicate
#' longer-lasting serial dependence.
last_lag_above_threshold <- function(lag, value, threshold = 0.10) {
  ok <- !is.na(value) & abs(value) >= threshold
  if (!any(ok)) return(NA_integer_)
  as.integer(max(lag[ok], na.rm = TRUE))
}

#' Summarise the memory content of an ACF curve.
#'
#' The function combines threshold-based and confidence-band-based criteria into
#' a small set of interpretable lag diagnostics.
summarise_acf_memory <- function(df,
                                 value_col = "acf",
                                 threshold = 0.10,
                                 consecutive = 3,
                                 conf_col = "conf_limit") {
  tibble::tibble(
    first_lag_abs_below_threshold_for_consecutive_lags = first_lag_run_below(
      lag = df$lag,
      value = df[[value_col]],
      threshold = threshold,
      consecutive = consecutive
    ),
    last_lag_abs_above_threshold = last_lag_above_threshold(
      lag = df$lag,
      value = df[[value_col]],
      threshold = threshold
    ),
    first_lag_inside_confidence_band_for_consecutive_lags = if (!is.null(conf_col) && conf_col %in% names(df)) {
      first_lag_run_inside_ci(
        lag = df$lag,
        value = df[[value_col]],
        limit = df[[conf_col]],
        consecutive = consecutive
      )
    } else {
      NA_integer_
    }
  )
}


# ============================================================
# 5. PSD AND SPECTRAL FEATURE FUNCTIONS
# ============================================================

# The PSD functions move the analysis from the time domain to the frequency
# domain. They estimate how the variance/power of the error is distributed
# across temporal frequencies and compute interpretable spectral summaries:
# low-frequency energy share, dominant frequency, spectral centroid and
# normalized spectral entropy.

#' Build the spectral taper used before FFT-based PSD estimation.
#'
#' A Hann taper is used by default to reduce spectral leakage. A rectangular
#' window is also available when no tapering is desired.
make_spectral_window <- function(n, type = "hann") {
  if (n <= 1) return(rep(1, n))
  type <- tolower(type)
  idx <- seq(0, n - 1)

  if (type == "rectangular") return(rep(1, n))
  if (type == "hann") return(0.5 - 0.5 * cos(2 * pi * idx / (n - 1)))

  stop("Unknown PSD window. Use 'rectangular' or 'hann'.")
}

#' Remove a linear trend from a numerical time series when feasible.
#'
#' Trend removal is optional. It can be useful when the PSD should focus on
#' oscillatory or stationary variability rather than long-term drift.
remove_linear_trend_safe <- function(x) {
  x <- as.numeric(x)
  if (length(x) < 3 || isTRUE(stats::sd(x, na.rm = TRUE) == 0)) return(x)
  t <- seq_along(x)
  fit <- stats::lm(x ~ t)
  as.numeric(stats::residuals(fit))
}

#' Estimate a one-sided power spectral density using an FFT periodogram.
#'
#' The function preprocesses the series, applies the selected window, computes
#' the two-sided periodogram, converts it to a one-sided PSD and returns the
#' corresponding frequency grid, period grid and energy-bin diagnostics.
compute_psd_vector <- function(x_original,
                               sampling_interval_days = 1,
                               remove_mean = TRUE,
                               remove_linear_trend = FALSE,
                               window_type = "hann") {
  x <- prepare_regular_series(x_original)

  n_eff <- sum(!is.na(x_original))
  n_total <- length(x_original)
  n_missing <- sum(is.na(x_original))
  missing_share <- ifelse(n_total > 0, n_missing / n_total, NA_real_)

  if (n_total < 4 || n_eff < 4 || all(is.na(x)) || isTRUE(stats::sd(x, na.rm = TRUE) == 0)) {
    return(tibble::tibble(
      frequency = numeric(), period_days = numeric(), psd = numeric(),
      df_frequency = numeric(), energy_bin = numeric(), n_eff = integer(),
      n_total = integer(), n_missing = integer(), missing_share = numeric(),
      time_mean_original = numeric(), time_sd_original = numeric(),
      time_variance_after_preprocessing = numeric(), total_power_psd = numeric()
    ))
  }

  time_mean_original <- mean(x, na.rm = TRUE)
  time_sd_original <- stats::sd(x, na.rm = TRUE)

  if (remove_mean) x <- x - mean(x, na.rm = TRUE)
  if (remove_linear_trend) x <- remove_linear_trend_safe(x)

  n <- length(x)
  dt <- sampling_interval_days
  df_freq <- 1 / (n * dt)

  w <- make_spectral_window(n, window_type)
  window_power_correction <- mean(w^2)

  xw <- x * w
  fft_x <- stats::fft(xw)

  # Two-sided periodogram corrected for the spectral-window power.
  psd_two_sided <- (dt / (n * window_power_correction)) * Mod(fft_x)^2

  # Non-negative frequencies, converted to one-sided PSD.
  if (n %% 2 == 0) {
    idx_nonnegative <- 1:(n / 2 + 1)
    interior_idx <- if (length(idx_nonnegative) > 2) 2:(length(idx_nonnegative) - 1) else integer(0)
  } else {
    idx_nonnegative <- 1:((n + 1) / 2)
    interior_idx <- if (length(idx_nonnegative) > 1) 2:length(idx_nonnegative) else integer(0)
  }

  frequency <- (idx_nonnegative - 1) * df_freq
  psd_one_sided <- psd_two_sided[idx_nonnegative]
  if (length(interior_idx) > 0) psd_one_sided[interior_idx] <- 2 * psd_one_sided[interior_idx]

  energy_bin <- psd_one_sided * df_freq
  total_power_psd <- sum(energy_bin, na.rm = TRUE)
  time_variance_after_preprocessing <- mean(x^2, na.rm = TRUE)

  tibble::tibble(
    frequency = frequency,
    period_days = ifelse(frequency > 0, 1 / frequency, Inf),
    psd = as.numeric(psd_one_sided),
    df_frequency = df_freq,
    energy_bin = as.numeric(energy_bin),
    n_eff = n_eff,
    n_total = n_total,
    n_missing = n_missing,
    missing_share = missing_share,
    time_mean_original = time_mean_original,
    time_sd_original = time_sd_original,
    time_variance_after_preprocessing = time_variance_after_preprocessing,
    total_power_psd = total_power_psd
  )
}

#' Compute the PSD from a station-level data frame.
#'
#' The data frame is ordered by date before the PSD is estimated, ensuring that
#' the FFT receives the daily sequence in the correct temporal order.
compute_psd_from_df <- function(df,
                                value_col = "error",
                                sampling_interval_days = 1,
                                remove_mean = TRUE,
                                remove_linear_trend = FALSE,
                                window_type = "hann") {
  df <- df %>% dplyr::arrange(date)
  compute_psd_vector(
    x_original = df[[value_col]],
    sampling_interval_days = sampling_interval_days,
    remove_mean = remove_mean,
    remove_linear_trend = remove_linear_trend,
    window_type = window_type
  )
}

#' Compute a trapezoidal numerical integral.
#'
#' The PSD is available on a discrete frequency grid. Trapezoidal integration is
#' used to approximate spectral energy over selected frequency bands.
trapz_integral <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  ok <- is.finite(x) & is.finite(y)
  x <- x[ok]
  y <- y[ok]
  if (length(x) < 2) return(NA_real_)
  ord <- order(x)
  x <- x[ord]
  y <- y[ord]
  sum(diff(x) * (head(y, -1) + tail(y, -1)) / 2)
}

#' Compute cumulative trapezoidal area along a frequency grid.
#'
#' This is used to build cumulative spectral-energy curves, i.e. the fraction of
#' total spectral energy accumulated up to each frequency.
cumulative_trapezoid <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  if (length(x) == 0) return(numeric())
  if (length(x) == 1) return(0)
  dx <- diff(x)
  area_increment <- dx * (head(y, -1) + tail(y, -1)) / 2
  c(0, cumsum(area_increment))
}

#' Prepare a clean frequency-PSD table for spectral integration.
#'
#' The function keeps finite, non-negative PSD values, sorts by frequency and
#' removes duplicated frequency points.
prepare_spectrum_xy <- function(df, psd_col = "psd") {
  df %>%
    dplyr::transmute(
      frequency = as.numeric(frequency),
      psd = as.numeric(.data[[psd_col]])
    ) %>%
    dplyr::filter(is.finite(frequency), is.finite(psd), psd >= 0) %>%
    dplyr::arrange(frequency) %>%
    dplyr::distinct(frequency, .keep_all = TRUE)
}

#' Add interpolated PSD values at selected frequency cutpoints.
#'
#' This improves band-energy estimates because the integration interval includes
#' the exact low/high-frequency boundary even when it is not originally present
#' in the FFT grid.
add_frequency_cutpoints_xy <- function(xy, cutpoints) {
  xy <- xy %>% dplyr::arrange(frequency)
  if (nrow(xy) < 2) return(xy)

  f_min <- min(xy$frequency, na.rm = TRUE)
  f_max <- max(xy$frequency, na.rm = TRUE)

  cutpoints <- cutpoints[is.finite(cutpoints)]
  cutpoints <- cutpoints[cutpoints >= f_min & cutpoints <= f_max]
  cutpoints <- setdiff(cutpoints, xy$frequency)

  if (length(cutpoints) == 0) return(xy)

  interp <- stats::approx(
    x = xy$frequency,
    y = xy$psd,
    xout = cutpoints,
    ties = "ordered",
    rule = 2
  )

  dplyr::bind_rows(
    xy,
    tibble::tibble(frequency = interp$x, psd = interp$y)
  ) %>%
    dplyr::arrange(frequency)
}

#' Integrate spectral energy over a selected frequency band.
#'
#' The function clips the requested band to the available frequency support and
#' performs trapezoidal integration on the augmented spectrum.
integrate_psd_band_xy <- function(xy, f_lower, f_upper) {
  xy <- xy %>% dplyr::arrange(frequency)
  if (nrow(xy) < 2) return(NA_real_)

  f_min <- min(xy$frequency, na.rm = TRUE)
  f_max <- max(xy$frequency, na.rm = TRUE)

  f_lower <- max(f_lower, f_min)
  f_upper <- min(f_upper, f_max)

  if (!is.finite(f_lower) || !is.finite(f_upper) || f_upper <= f_lower) return(NA_real_)

  xy_aug <- add_frequency_cutpoints_xy(xy, c(f_lower, f_upper))
  xy_band <- xy_aug %>%
    dplyr::filter(frequency >= f_lower, frequency <= f_upper) %>%
    dplyr::arrange(frequency)

  trapz_integral(xy_band$frequency, xy_band$psd)
}

#' Add cumulative spectral energy and normalized cumulative energy share.
#'
#' The resulting cumulative-energy curve is useful for identifying which
#' frequency range accounts for a given fraction of the total error power.
add_cumulative_energy <- function(df, psd_col = "mean_psd") {
  df <- df %>% dplyr::arrange(frequency)
  cumulative_energy <- cumulative_trapezoid(df$frequency, df[[psd_col]])
  total_energy <- ifelse(length(cumulative_energy) > 0, tail(cumulative_energy, 1), NA_real_)

  df %>%
    dplyr::mutate(
      cumulative_energy = cumulative_energy,
      total_energy = total_energy,
      cumulative_energy_share = ifelse(
        is.finite(total_energy) & total_energy > PSD_EPS,
        cumulative_energy / total_energy,
        NA_real_
      )
    )
}

#' Extract the frequency at which selected cumulative-energy shares are reached.
#'
#' For example, the 0.80 threshold gives the frequency below which 80% of the
#' aggregated spectral energy is accumulated.
extract_energy_thresholds <- function(df, levels = c(0.50, 0.80, 0.90, 0.95)) {
  purrr::map_dfr(levels, function(level_i) {
    df_i <- df %>%
      dplyr::filter(!is.na(cumulative_energy_share)) %>%
      dplyr::arrange(frequency)

    if (nrow(df_i) == 0 || max(df_i$cumulative_energy_share, na.rm = TRUE) < level_i) {
      return(tibble::tibble(
        energy_share = level_i,
        frequency_threshold = NA_real_,
        period_days_threshold = NA_real_
      ))
    }

    first_idx <- which(df_i$cumulative_energy_share >= level_i)[1]
    f_thr <- df_i$frequency[first_idx]
    tibble::tibble(
      energy_share = level_i,
      frequency_threshold = f_thr,
      period_days_threshold = ifelse(f_thr > 0, 1 / f_thr, Inf)
    )
  })
}

#' Compute scalar spectral descriptors from a PSD.
#'
#' The exported features include low/high-frequency energy, low-frequency share,
#' dominant frequency, spectral centroid and normalized entropy. These quantities
#' summarize persistence, dominant time scale and spectral concentration.
compute_spectral_features_from_psd <- function(df,
                                               psd_col = "psd",
                                               f_critical = 0.20,
                                               dominant_exclude_zero = TRUE) {
  xy <- prepare_spectrum_xy(df, psd_col = psd_col)

  empty_features <- tibble::tibble(
    frequency_critical = f_critical,
    period_critical_days = ifelse(f_critical > 0, 1 / f_critical, Inf),
    frequency_max = NA_real_,
    energy_low = NA_real_,
    energy_high = NA_real_,
    energy_total = NA_real_,
    R_low = NA_real_,
    R_high = NA_real_,
    low_high_ratio = NA_real_,
    high_low_ratio = NA_real_,
    dominant_frequency = NA_real_,
    dominant_period_days = NA_real_,
    spectral_centroid = NA_real_,
    spectral_centroid_period_days = NA_real_,
    spectral_entropy = NA_real_,
    spectral_entropy_normalized = NA_real_
  )

  if (nrow(xy) < 2) return(empty_features)

  f_min <- min(xy$frequency, na.rm = TRUE)
  f_max <- max(xy$frequency, na.rm = TRUE)
  f_lower <- max(0, f_min)
  f_critical_used <- min(max(f_critical, f_lower), f_max)

  xy_aug <- add_frequency_cutpoints_xy(xy, c(f_lower, f_critical_used, f_max))

  energy_low <- integrate_psd_band_xy(xy_aug, f_lower = f_lower, f_upper = f_critical_used)
  energy_high <- integrate_psd_band_xy(xy_aug, f_lower = f_critical_used, f_upper = f_max)
  energy_total <- energy_low + energy_high

  R_low <- ifelse(is.finite(energy_total) && energy_total > PSD_EPS, energy_low / energy_total, NA_real_)
  R_high <- ifelse(is.finite(energy_total) && energy_total > PSD_EPS, energy_high / energy_total, NA_real_)

  low_high_ratio <- ifelse(is.finite(energy_high) && energy_high > PSD_EPS, energy_low / energy_high, NA_real_)
  high_low_ratio <- ifelse(is.finite(energy_low) && energy_low > PSD_EPS, energy_high / energy_low, NA_real_)

  xy_dom <- xy
  if (dominant_exclude_zero) xy_dom <- xy_dom %>% dplyr::filter(frequency > 0)
  if (nrow(xy_dom) > 0 && any(is.finite(xy_dom$psd))) {
    dom_idx <- which.max(xy_dom$psd)
    dominant_frequency <- xy_dom$frequency[dom_idx]
  } else {
    dominant_frequency <- NA_real_
  }

  total_psd_mass <- sum(xy$psd, na.rm = TRUE)
  spectral_centroid <- ifelse(
    is.finite(total_psd_mass) && total_psd_mass > PSD_EPS,
    sum(xy$frequency * xy$psd, na.rm = TRUE) / total_psd_mass,
    NA_real_
  )

  p <- xy$psd / total_psd_mass
  p <- p[is.finite(p) & p > 0]
  spectral_entropy <- if (length(p) > 0) -sum(p * log(p)) else NA_real_
  spectral_entropy_normalized <- ifelse(
    length(p) > 1 && is.finite(spectral_entropy),
    spectral_entropy / log(length(p)),
    NA_real_
  )

  tibble::tibble(
    frequency_critical = f_critical_used,
    period_critical_days = ifelse(f_critical_used > 0, 1 / f_critical_used, Inf),
    frequency_max = f_max,
    energy_low = energy_low,
    energy_high = energy_high,
    energy_total = energy_total,
    R_low = R_low,
    R_high = R_high,
    low_high_ratio = low_high_ratio,
    high_low_ratio = high_low_ratio,
    dominant_frequency = dominant_frequency,
    dominant_period_days = ifelse(!is.na(dominant_frequency) & dominant_frequency > 0, 1 / dominant_frequency, Inf),
    spectral_centroid = spectral_centroid,
    spectral_centroid_period_days = ifelse(!is.na(spectral_centroid) & spectral_centroid > 0, 1 / spectral_centroid, Inf),
    spectral_entropy = spectral_entropy,
    spectral_entropy_normalized = spectral_entropy_normalized
  )
}


# ============================================================
# 6. FIR FILTER FUNCTIONS WITH GROUP-DELAY CORRECTION
# ============================================================

# This block implements the FIR low-pass/high-pass decomposition. The central
# methodological point is that the low-pass filter is causal and therefore
# delayed; the code corrects this group delay explicitly before comparing the
# low-pass and high-pass components with the centered error.

#' Evaluate the normalized sinc function sin(pi x)/(pi x).
#'
#' The removable singularity at x = 0 is handled explicitly by assigning the
#' limiting value equal to one.
sinc_normalized <- function(x) {
  x <- as.numeric(x)
  out <- rep(NA_real_, length(x))
  zero_idx <- abs(x) < 1e-12
  out[zero_idx] <- 1
  out[!zero_idx] <- sin(pi * x[!zero_idx]) / (pi * x[!zero_idx])
  out
}

#' Build the time-domain window used in the FIR design.
#'
#' Windowing truncates the ideal sinc response while controlling side lobes in
#' the frequency response. Hamming is used by default for a smoother transition
#' than a rectangular truncation.
make_fir_window <- function(n, type = "hamming") {
  if (n <= 1) return(rep(1, n))
  type <- tolower(type)
  idx <- seq(0, n - 1)

  if (type == "rectangular") return(rep(1, n))
  if (type == "hann") return(0.5 - 0.5 * cos(2 * pi * idx / (n - 1)))
  if (type == "hamming") return(0.54 - 0.46 * cos(2 * pi * idx / (n - 1)))

  stop("Unknown FIR window. Use 'rectangular', 'hann' or 'hamming'.")
}

#' Design a windowed-sinc FIR low-pass filter and its complementary high-pass.
#'
#' The filter order M must be even so that the group delay K = M/2 is an integer.
#' The complementary high-pass filter is constructed as delta_K - h, not as a
#' naive pointwise residual after filtering.
make_fir_lowpass_windowed_sinc <- function(M,
                                           f_cutoff,
                                           window_type = "hamming",
                                           normalize_dc_gain = TRUE) {
  if (!is.finite(M) || M < 1 || M != as.integer(M)) {
    stop("FIR_ORDER_M must be a positive integer.")
  }
  if (M %% 2 != 0) {
    stop("FIR_ORDER_M must be even in this pipeline, because K = M/2 must be an integer.")
  }
  if (!is.finite(f_cutoff) || f_cutoff <= 0 || f_cutoff >= 0.5) {
    stop("FIR_CUTOFF_FREQUENCY must lie in (0, 0.5) cycles/day.")
  }

  ell <- 0:M
  K <- M / 2
  n_taps <- M + 1

  h_ideal <- 2 * f_cutoff * sinc_normalized(2 * f_cutoff * (ell - K))
  window <- make_fir_window(n_taps, window_type)
  h <- h_ideal * window

  if (normalize_dc_gain) h <- h / sum(h)

  g <- -h
  g[K + 1] <- g[K + 1] + 1

  tibble::tibble(
    ell = ell,
    h_lowpass = as.numeric(h),
    g_highpass_complement = as.numeric(g),
    delta_at_group_delay = as.numeric(ell == K),
    h_ideal = as.numeric(h_ideal),
    window = as.numeric(window),
    M = M,
    K_group_delay_days = K,
    n_taps = n_taps,
    f_cutoff = f_cutoff,
    period_cutoff_days = 1 / f_cutoff,
    window_type = window_type,
    lowpass_dc_gain = sum(h),
    highpass_dc_gain = sum(g)
  )
}

#' Apply a causal FIR filter to a numerical time series.
#'
#' For each output index i, the function uses current and past samples only.
#' Outputs are NA until the full filter support is available.
apply_causal_fir <- function(x, coefficients) {
  x <- as.numeric(x)
  coefficients <- as.numeric(coefficients)
  n <- length(x)
  M <- length(coefficients) - 1
  y <- rep(NA_real_, n)

  if (n == 0 || length(coefficients) == 0) return(y)

  for (i in seq_along(x)) {
    idx <- i - (0:M)
    if (all(idx >= 1)) {
      x_lagged <- x[idx]
      if (all(is.finite(x_lagged))) {
        y[i] <- sum(coefficients * x_lagged)
      }
    }
  }
  y
}

#' Compute the discrete-time frequency response of FIR coefficients.
#'
#' The response is evaluated on the [0, 0.5] cycles/day range, corresponding to
#' the non-negative frequencies up to the Nyquist frequency for daily sampling.
compute_fir_frequency_response <- function(coefficients, n_frequency = 2001) {
  coefficients <- as.numeric(coefficients)
  ell <- 0:(length(coefficients) - 1)
  frequency <- seq(0, 0.5, length.out = n_frequency)

  H <- vapply(
    frequency,
    function(f) sum(coefficients * exp(-1i * 2 * pi * f * ell)),
    complex(1)
  )

  tibble::tibble(
    frequency = frequency,
    period_days = ifelse(frequency > 0, 1 / frequency, Inf),
    magnitude = Mod(H),
    magnitude_db = 20 * log10(pmax(Mod(H), 1e-12)),
    power_gain = Mod(H)^2,
    phase = Arg(H)
  )
}

#' Decompose a station-level error series into static, low-pass and high-pass parts.
#'
#' First, the station-specific static bias alpha_s is estimated and removed.
#' Then the centered error is filtered by the low-pass and complementary high-pass
#' FIR filters. Finally, causal outputs are shifted back by the group delay so
#' that the decomposition identity is evaluated at the correct centered date.
compute_group_delay_aligned_decomposition <- function(df, h, g, K) {
  df <- df %>% dplyr::arrange(date)
  error_original <- as.numeric(df$error)

  n_total <- length(error_original)
  n_eff <- sum(!is.na(error_original))
  n_missing <- sum(is.na(error_original))
  missing_share <- ifelse(n_total > 0, n_missing / n_total, NA_real_)

  alpha_static <- mean(error_original, na.rm = TRUE)

  if (!is.finite(alpha_static) || n_eff < 3) {
    return(tibble::tibble(
      date = df$date,
      center_index = seq_len(n_total),
      causal_output_index = NA_integer_,
      causal_output_date = as.Date(NA),
      error_original = error_original,
      error_filled = NA_real_,
      alpha_static = alpha_static,
      centered_error = NA_real_,
      lowpass_component = NA_real_,
      highpass_residual = NA_real_,
      identity_error = NA_real_,
      valid_group_delay_alignment = FALSE,
      n_eff = n_eff,
      n_total = n_total,
      n_missing = n_missing,
      missing_share = missing_share
    ))
  }

  error_filled <- prepare_regular_series(error_original)
  centered_error <- error_filled - alpha_static

  lowpass_causal <- apply_causal_fir(centered_error, h)
  highpass_causal <- apply_causal_fir(centered_error, g)

  center_index <- seq_len(n_total)
  causal_output_index <- center_index + K
  valid_index <- causal_output_index <= n_total

  lowpass_aligned <- rep(NA_real_, n_total)
  highpass_aligned <- rep(NA_real_, n_total)
  causal_output_date <- rep(as.Date(NA), n_total)

  lowpass_aligned[valid_index] <- lowpass_causal[causal_output_index[valid_index]]
  highpass_aligned[valid_index] <- highpass_causal[causal_output_index[valid_index]]
  causal_output_date[valid_index] <- df$date[causal_output_index[valid_index]]

  valid_group_delay_alignment <- is.finite(centered_error) & is.finite(lowpass_aligned) & is.finite(highpass_aligned)
  identity_error <- centered_error - lowpass_aligned - highpass_aligned

  tibble::tibble(
    date = df$date,
    center_index = center_index,
    causal_output_index = ifelse(valid_index, causal_output_index, NA_integer_),
    causal_output_date = causal_output_date,
    error_original = error_original,
    error_filled = error_filled,
    alpha_static = alpha_static,
    centered_error = centered_error,
    lowpass_component = lowpass_aligned,
    highpass_residual = highpass_aligned,
    identity_error = identity_error,
    valid_group_delay_alignment = valid_group_delay_alignment,
    n_eff = n_eff,
    n_total = n_total,
    n_missing = n_missing,
    missing_share = missing_share
  )
}

#' Convert internal component codes into publication-friendly labels.
#'
#' These labels are used consistently in exported tables and figures.
component_label_from_code <- function(component) {
  dplyr::case_when(
    component == "centered_error" ~ "Centered error",
    component == "lowpass_component" ~ "Low-pass component",
    component == "highpass_residual" ~ "High-pass residual",
    TRUE ~ as.character(component)
  )
}


# ============================================================
# 7. LJUNG-BOX FUNCTIONS
# ============================================================

# The Ljung-Box test is used as a residual diagnostic. Here it evaluates whether
# the high-pass residual still contains statistically detectable autocorrelation
# up to selected lags after the persistent low-frequency component has been
# removed.

#' Run Ljung-Box tests at multiple lags for a univariate series.
#'
#' The null hypothesis is absence of autocorrelation up to the selected lag.
#' Rejecting the null indicates residual serial dependence.
compute_ljung_box_vector <- function(x_original,
                                     lags = c(5, 10, 20),
                                     alpha = 0.05,
                                     fitdf = 0) {
  x <- prepare_regular_series(x_original)
  x <- x[is.finite(x)]

  n_eff <- length(x)
  if (n_eff < 5 || isTRUE(stats::sd(x, na.rm = TRUE) == 0)) {
    return(tibble::tibble(
      ljung_box_lag = lags,
      statistic = NA_real_,
      p_value = NA_real_,
      n_eff = n_eff,
      reject_H0_autocorrelation_absent = NA,
      do_not_reject_H0_no_autocorrelation = NA
    ))
  }

  purrr::map_dfr(lags, function(lag_i) {
    lag_used <- min(lag_i, n_eff - 1)
    if (lag_used <= fitdf || lag_used < 1) {
      return(tibble::tibble(
        ljung_box_lag = lag_i,
        statistic = NA_real_,
        p_value = NA_real_,
        n_eff = n_eff,
        reject_H0_autocorrelation_absent = NA,
        do_not_reject_H0_no_autocorrelation = NA
      ))
    }

    test <- stats::Box.test(x, lag = lag_used, type = "Ljung-Box", fitdf = fitdf)
    p_val <- as.numeric(test$p.value)

    tibble::tibble(
      ljung_box_lag = lag_i,
      statistic = as.numeric(test$statistic),
      p_value = p_val,
      n_eff = n_eff,
      reject_H0_autocorrelation_absent = p_val < alpha,
      do_not_reject_H0_no_autocorrelation = p_val >= alpha
    )
  })
}


# ============================================================
# 8. PLOTTING FUNCTIONS
# ============================================================

# Plotting functions are kept modular to ensure consistent visual styling and
# avoid duplicating ggplot code throughout the analysis. They produce repository
# figures that can be directly used in reports or slide decks.

#' Plot station-level ACF curves in a faceted layout.
#'
#' This visualization is useful when inspecting heterogeneity across stations.
plot_acf_faceted <- function(acf_data, title_text, subtitle_text = NULL) {
  ggplot(acf_data, aes(x = lag, y = acf)) +
    geom_hline(yintercept = 0, linewidth = 0.35) +
    geom_hline(aes(yintercept = conf_limit), linetype = "dashed", linewidth = 0.25) +
    geom_hline(aes(yintercept = -conf_limit), linetype = "dashed", linewidth = 0.25) +
    geom_segment(aes(xend = lag, y = 0, yend = acf), linewidth = 0.35) +
    geom_point(size = 0.8) +
    facet_wrap(~ station, scales = "free_y") +
    labs(
      title = title_text,
      subtitle = subtitle_text,
      x = "Lag [days]",
      y = "Autocorrelation"
    ) +
    theme_bw() +
    theme(
      strip.text = element_text(size = 7),
      plot.title = element_text(size = 13, face = "bold"),
      plot.subtitle = element_text(size = 10)
    )
}

#' Plot the mean ACF across stations with an interquartile ribbon.
#'
#' The mean curve summarizes the typical temporal memory, while the ribbon shows
#' station-to-station dispersion.
plot_mean_acf <- function(acf_mean_data, title_text, subtitle_text = NULL) {
  ggplot(acf_mean_data, aes(x = lag, y = mean_acf, linetype = temperature_type, shape = temperature_type)) +
    geom_hline(yintercept = 0, linewidth = 0.35) +
    geom_ribbon(aes(ymin = q25_acf, ymax = q75_acf, fill = temperature_type), alpha = 0.12, linewidth = 0) +
    geom_line(linewidth = 0.75) +
    geom_point(size = 1.2) +
    labs(
      title = title_text,
      subtitle = subtitle_text,
      x = "Lag [days]",
      y = "Mean ACF across stations",
      linetype = "Temperature type",
      shape = "Temperature type",
      fill = "Temperature type"
    ) +
    theme_bw() +
    theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))
}

#' Plot the aggregated PSD across stations.
#'
#' The y-axis is shown on a logarithmic scale because spectral power often varies
#' by orders of magnitude across frequencies.
plot_psd_aggregated <- function(psd_data, title_text, subtitle_text = NULL) {
  ggplot(psd_data %>% dplyr::filter(frequency > 0, mean_psd > 0),
         aes(x = frequency, y = mean_psd, linetype = temperature_type)) +
    geom_vline(xintercept = PSD_CRITICAL_FREQUENCY, linetype = "dashed", linewidth = 0.35) +
    geom_line(linewidth = 0.75) +
    scale_y_log10() +
    labs(
      title = title_text,
      subtitle = subtitle_text,
      x = "Frequency [cycles/day]",
      y = "Mean PSD across stations, log scale",
      linetype = "Temperature type"
    ) +
    theme_bw() +
    theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))
}


# ============================================================
# 9. LOAD AND CLEAN DATASET
# ============================================================

# This block imports the Excel file, standardizes column names and converts dates
# and numerical variables to analysis-ready formats. The code checks that all
# required columns are present before any statistical calculation is performed.

if (!file.exists(file_path)) {
  stop(paste0("Excel file not found: ", file_path, "\nEdit file_path in section 0."))
}

available_sheets <- readxl::excel_sheets(file_path)
cat("\nAvailable Excel sheets:\n")
print(available_sheets)

if (!sheet_name %in% available_sheets) {
  stop(paste0(
    "Sheet '", sheet_name, "' not found. Available sheets: ",
    paste(available_sheets, collapse = ", ")
  ))
}

data_original <- readxl::read_excel(path = file_path, sheet = sheet_name)
data_raw <- data_original %>% janitor::clean_names()

cat("\nColumn names after janitor::clean_names():\n")
print(names(data_raw))
cat("\nImported dataset dimensions:\n")
print(dim(data_raw))

required_base_cols <- c("station", "date", "next_tmax", "next_tmin", "ldaps_tmax_lapse", "ldaps_tmin_lapse")
missing_base_cols <- setdiff(required_base_cols, names(data_raw))

if (length(missing_base_cols) > 0) {
  stop(paste(
    "The dataset is missing required columns:",
    paste(missing_base_cols, collapse = ", ")
  ))
}

# Convert the two structural identifiers first:
#   - date is mapped to Date, because chronological ordering is required later;
#   - station is kept as character, because station identifiers are categorical
#     labels rather than numerical quantities.
data_clean <- data_raw %>%
  dplyr::mutate(
    date = parse_date_safe(date),
    station = as.character(station)
  )

# All remaining columns are treated as candidate numerical variables. This is
# appropriate for the present dataset, where non-date/non-station columns encode
# observed temperatures, forecast temperatures, meteorological covariates or
# precomputed errors.
numeric_cols <- setdiff(names(data_clean), c("date", "station"))

data_clean <- data_clean %>%
  dplyr::mutate(
    dplyr::across(dplyr::all_of(numeric_cols), parse_num_safe),
    station_id = factor(station)
  )

if (any(is.na(data_clean$date))) {
  warning("Some dates could not be parsed and are NA. Check diagnostics outputs.")
}

readr::write_csv(
  tibble::tibble(column_name = names(data_clean)),
  file.path(output_dir, "diagnostics", "clean_column_names.csv")
)


# ============================================================
# 10. ERROR DEFINITION AND CONSISTENCY CHECK
# ============================================================

# This block reconstructs Tmin/Tmax errors from observed and forecast variables
# and compares them with possible pre-existing error columns. The consistency
# check protects the analysis from sign-convention mistakes, which would reverse
# the interpretation of underestimation and overestimation.

# Robust handling of possible existing error columns.
if (!"errore_tmax" %in% names(data_clean) && "error_tmax" %in% names(data_clean)) {
  data_clean <- data_clean %>% dplyr::rename(errore_tmax = error_tmax)
}
if (!"errore_tmin" %in% names(data_clean) && "error_tmin" %in% names(data_clean)) {
  data_clean <- data_clean %>% dplyr::rename(errore_tmin = error_tmin)
}

# Reconstruct errors directly from the observed and forecast columns. This step
# makes the sign convention explicit and provides a benchmark against which any
# pre-existing error column can be checked.
data_clean <- data_clean %>%
  dplyr::mutate(
    reconstructed_error_tmax = next_tmax - ldaps_tmax_lapse,
    reconstructed_error_tmin = next_tmin - ldaps_tmin_lapse
  )

if ("errore_tmax" %in% names(data_clean)) {
  data_clean <- data_clean %>%
    dplyr::mutate(
      check_existing_error_tmax = errore_tmax - reconstructed_error_tmax,
      error_tmax = errore_tmax
    )
} else {
  data_clean <- data_clean %>%
    dplyr::mutate(
      check_existing_error_tmax = NA_real_,
      error_tmax = reconstructed_error_tmax
    )
}

if ("errore_tmin" %in% names(data_clean)) {
  data_clean <- data_clean %>%
    dplyr::mutate(
      check_existing_error_tmin = errore_tmin - reconstructed_error_tmin,
      error_tmin = errore_tmin
    )
} else {
  data_clean <- data_clean %>%
    dplyr::mutate(
      check_existing_error_tmin = NA_real_,
      error_tmin = reconstructed_error_tmin
    )
}

error_consistency_check <- data_clean %>%
  dplyr::summarise(
    max_abs_check_tmax = ifelse(all(is.na(check_existing_error_tmax)), NA_real_, max(abs(check_existing_error_tmax), na.rm = TRUE)),
    max_abs_check_tmin = ifelse(all(is.na(check_existing_error_tmin)), NA_real_, max(abs(check_existing_error_tmin), na.rm = TRUE)),
    mean_abs_check_tmax = ifelse(all(is.na(check_existing_error_tmax)), NA_real_, mean(abs(check_existing_error_tmax), na.rm = TRUE)),
    mean_abs_check_tmin = ifelse(all(is.na(check_existing_error_tmin)), NA_real_, mean(abs(check_existing_error_tmin), na.rm = TRUE))
  )

cat("\nError consistency check against observed - forecast convention:\n")
print(error_consistency_check)

readr::write_csv(
  error_consistency_check,
  file.path(output_dir, "diagnostics", "error_consistency_check.csv")
)


# ============================================================
# 11. BUILD REGULAR STATION-DATE ERROR SERIES
# ============================================================

# This block constructs the station-level daily error series used by the ACF,
# PSD and filtering modules. Duplicate station-date records are detected and
# averaged; missing dates are inserted so that every station is represented on a
# common daily grid.

data_clean <- data_clean %>%
  dplyr::arrange(station, date) %>%
  dplyr::group_by(station) %>%
  dplyr::mutate(time_index_station = dplyr::row_number()) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    year = lubridate::year(date),
    month = lubridate::month(date),
    day = lubridate::day(date),
    yday = lubridate::yday(date)
  )

duplicate_station_date <- data_clean %>%
  dplyr::count(station, date, name = "n_records") %>%
  dplyr::filter(n_records > 1) %>%
  dplyr::arrange(dplyr::desc(n_records), station, date)

readr::write_csv(
  duplicate_station_date,
  file.path(output_dir, "diagnostics", "duplicate_station_date_rows.csv")
)

if (nrow(duplicate_station_date) > 0) {
  warning("Duplicate station-date rows detected. Errors will be averaged by station-date.")
}

# Collapse possible duplicate station-date records. If multiple rows refer to
# the same station and day, their error values are averaged. This creates a
# unique daily observation per station before the time-series grid is completed.
data_series_clean <- data_clean %>%
  dplyr::group_by(station, date) %>%
  dplyr::summarise(
    error_tmin = mean(error_tmin, na.rm = TRUE),
    error_tmax = mean(error_tmax, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    error_tmin = ifelse(is.nan(error_tmin), NA_real_, error_tmin),
    error_tmax = ifelse(is.nan(error_tmax), NA_real_, error_tmax)
  ) %>%
  dplyr::arrange(station, date)

# Reshape Tmin and Tmax into a common long format. This allows the same ACF,
# PSD, filtering and diagnostic functions to be applied uniformly to both
# temperature variables.
error_long <- dplyr::bind_rows(
  data_series_clean %>% dplyr::transmute(station, date, temperature_type = "Tmin", error = error_tmin),
  data_series_clean %>% dplyr::transmute(station, date, temperature_type = "Tmax", error = error_tmax)
) %>%
  dplyr::mutate(temperature_type = factor(temperature_type, levels = c("Tmin", "Tmax"))) %>%
  dplyr::arrange(temperature_type, station, date)

date_grid <- sort(unique(data_series_clean$date))

# Complete the station-date grid. The result is a regular daily panel indexed
# by temperature type, station and date. Missing measurements remain NA at this
# stage and are handled inside the time-series helper functions.
error_long_complete <- error_long %>%
  dplyr::group_by(temperature_type, station) %>%
  tidyr::complete(date = date_grid) %>%
  dplyr::arrange(temperature_type, station, date) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(temperature_type = factor(temperature_type, levels = c("Tmin", "Tmax")))

series_missing_diagnostics <- error_long_complete %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::summarise(
    n_total_grid = dplyr::n(),
    n_non_missing_error = sum(!is.na(error)),
    n_missing_after_grid_completion = sum(is.na(error)),
    missing_share_after_grid_completion = n_missing_after_grid_completion / n_total_grid,
    date_min = min(date, na.rm = TRUE),
    date_max = max(date, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(temperature_type, station)

readr::write_csv(error_long, file.path(output_dir, "series", "error_long_raw_grid.csv"))
readr::write_csv(error_long_complete, file.path(output_dir, "series", "error_long_complete_station_date_grid.csv"))
readr::write_csv(series_missing_diagnostics, file.path(output_dir, "series", "series_missing_diagnostics.csv"))

cat("\nNumber of stations in the completed error series:\n")
print(dplyr::n_distinct(error_long_complete$station))


# ============================================================
# 12. BASELINE ACF ANALYSIS ON ORIGINAL ERROR SERIES
# ============================================================

# This block estimates the autocorrelation structure of the original forecast
# error before filtering. Station-level ACFs are computed first, then summarized
# across stations separately for Tmin and Tmax.

# Compute the baseline ACF independently for each station and temperature type.
# This station-first strategy avoids mixing local time-series structures before
# estimating memory.
baseline_acf_all_stations <- error_long_complete %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::group_modify(~ compute_acf_from_df(.x, value_col = "error", max_lag = max_lag, include_lag0 = include_lag0)) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, station, lag)

baseline_acf_mean <- baseline_acf_all_stations %>%
  dplyr::group_by(temperature_type, lag) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station[!is.na(acf)]),
    mean_acf = mean(acf, na.rm = TRUE),
    median_acf = median(acf, na.rm = TRUE),
    sd_acf = safe_sd(acf),
    se_acf = ifelse(n_stations > 1, sd_acf / sqrt(n_stations), NA_real_),
    q05_acf = stats::quantile(acf, probs = 0.05, na.rm = TRUE),
    q25_acf = stats::quantile(acf, probs = 0.25, na.rm = TRUE),
    q75_acf = stats::quantile(acf, probs = 0.75, na.rm = TRUE),
    q95_acf = stats::quantile(acf, probs = 0.95, na.rm = TRUE),
    lower_mean_95 = mean_acf - 1.96 * se_acf,
    upper_mean_95 = mean_acf + 1.96 * se_acf,
    .groups = "drop"
  ) %>%
  dplyr::arrange(temperature_type, lag)

baseline_acf_memory_by_station <- baseline_acf_all_stations %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::group_modify(~ summarise_acf_memory(
    .x,
    value_col = "acf",
    threshold = ACF_MEMORY_THRESHOLD,
    consecutive = ACF_MEMORY_CONSECUTIVE_LAGS,
    conf_col = "conf_limit"
  )) %>%
  dplyr::ungroup()

readr::write_csv(baseline_acf_all_stations, file.path(output_dir, "baseline_acf", "baseline_acf_all_stations.csv"))
readr::write_csv(baseline_acf_mean, file.path(output_dir, "baseline_acf", "baseline_acf_mean_across_stations.csv"))
readr::write_csv(baseline_acf_memory_by_station, file.path(output_dir, "baseline_acf", "baseline_acf_memory_by_station.csv"))

plot_baseline_mean_acf <- plot_mean_acf(
  baseline_acf_mean,
  title_text = "Baseline mean ACF of forecast error",
  subtitle_text = "Ribbon: interquartile range across stations. Error convention: observed - forecast."
)

print(plot_baseline_mean_acf)
ggsave(file.path(output_dir, "baseline_acf", "baseline_mean_acf_tmin_tmax.png"),
       plot_baseline_mean_acf, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 13. BASELINE PSD ANALYSIS ON ORIGINAL ERROR SERIES
# ============================================================

# This block estimates the baseline spectral composition of the original error.
# The PSD is computed station by station and then aggregated across stations.
# Cumulative spectral energy and low/high-frequency energy ratios are exported
# as quantitative summaries of the error time scale.

# Compute the baseline PSD independently for each station. PSD aggregation is
# performed only after station-level spectra have been estimated on comparable
# daily grids.
baseline_psd_all_stations <- error_long_complete %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::group_modify(~ compute_psd_from_df(
    .x,
    value_col = "error",
    sampling_interval_days = PSD_SAMPLING_INTERVAL_DAYS,
    remove_mean = PSD_REMOVE_MEAN_BASELINE,
    remove_linear_trend = PSD_REMOVE_LINEAR_TREND_BASELINE,
    window_type = PSD_WINDOW
  )) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, station, frequency)

baseline_psd_aggregated <- baseline_psd_all_stations %>%
  dplyr::group_by(temperature_type, frequency) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station[!is.na(psd)]),
    mean_psd = mean(psd, na.rm = TRUE),
    median_psd = median(psd, na.rm = TRUE),
    sd_psd = safe_sd(psd),
    se_psd = ifelse(n_stations > 1, sd_psd / sqrt(n_stations), NA_real_),
    q05_psd = stats::quantile(psd, probs = 0.05, na.rm = TRUE),
    q25_psd = stats::quantile(psd, probs = 0.25, na.rm = TRUE),
    q75_psd = stats::quantile(psd, probs = 0.75, na.rm = TRUE),
    q95_psd = stats::quantile(psd, probs = 0.95, na.rm = TRUE),
    df_frequency = dplyr::first(df_frequency),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    period_days = ifelse(frequency > 0, 1 / frequency, Inf),
    lower_mean_95 = mean_psd - 1.96 * se_psd,
    upper_mean_95 = mean_psd + 1.96 * se_psd
  ) %>%
  dplyr::arrange(temperature_type, frequency)

baseline_psd_cumulative_energy <- baseline_psd_aggregated %>%
  dplyr::group_by(temperature_type) %>%
  dplyr::group_modify(~ add_cumulative_energy(.x, psd_col = "mean_psd")) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, frequency)

baseline_psd_energy_thresholds <- baseline_psd_cumulative_energy %>%
  dplyr::group_by(temperature_type) %>%
  dplyr::group_modify(~ extract_energy_thresholds(.x, levels = c(0.50, 0.80, 0.90, 0.95))) %>%
  dplyr::ungroup()

baseline_spectral_features_aggregated <- baseline_psd_aggregated %>%
  dplyr::group_by(temperature_type) %>%
  dplyr::group_modify(~ compute_spectral_features_from_psd(
    .x,
    psd_col = "mean_psd",
    f_critical = PSD_CRITICAL_FREQUENCY,
    dominant_exclude_zero = PSD_DOMINANT_EXCLUDE_ZERO
  )) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(level = "aggregated")

baseline_spectral_features_by_station <- baseline_psd_all_stations %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::group_modify(~ compute_spectral_features_from_psd(
    .x,
    psd_col = "psd",
    f_critical = PSD_CRITICAL_FREQUENCY,
    dominant_exclude_zero = PSD_DOMINANT_EXCLUDE_ZERO
  )) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(level = "station")

readr::write_csv(baseline_psd_all_stations, file.path(output_dir, "baseline_psd", "station_level", "baseline_psd_all_stations.csv"))
readr::write_csv(baseline_psd_aggregated, file.path(output_dir, "baseline_psd", "aggregated", "baseline_psd_aggregated.csv"))
readr::write_csv(baseline_psd_cumulative_energy, file.path(output_dir, "baseline_psd", "cumulative_energy", "baseline_psd_cumulative_energy.csv"))
readr::write_csv(baseline_psd_energy_thresholds, file.path(output_dir, "baseline_psd", "cumulative_energy", "baseline_psd_energy_thresholds.csv"))
readr::write_csv(baseline_spectral_features_aggregated, file.path(output_dir, "baseline_psd", "spectral_features", "baseline_spectral_features_aggregated.csv"))
readr::write_csv(baseline_spectral_features_by_station, file.path(output_dir, "baseline_psd", "spectral_features", "baseline_spectral_features_by_station.csv"))

plot_baseline_psd <- plot_psd_aggregated(
  baseline_psd_aggregated,
  title_text = "Baseline aggregated PSD of forecast error",
  subtitle_text = paste0("Dashed vertical line: f_c = ", PSD_CRITICAL_FREQUENCY, " cycles/day, corresponding to ", PSD_CRITICAL_PERIOD_DAYS, " days.")
)

plot_baseline_cumulative_energy <- ggplot(
  baseline_psd_cumulative_energy,
  aes(x = frequency, y = cumulative_energy_share, linetype = temperature_type, shape = temperature_type)
) +
  geom_hline(yintercept = c(0.50, 0.80, 0.90, 0.95), linetype = "dotted", linewidth = 0.3) +
  geom_vline(xintercept = PSD_CRITICAL_FREQUENCY, linetype = "dashed", linewidth = 0.35) +
  geom_line(linewidth = 0.75) +
  geom_point(size = 1.1) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    title = "Baseline cumulative spectral energy",
    subtitle = "The 0.2 cycles/day threshold corresponds to a 5-day time scale.",
    x = "Frequency [cycles/day]",
    y = "Cumulative spectral-energy share",
    linetype = "Temperature type",
    shape = "Temperature type"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

print(plot_baseline_psd)
print(plot_baseline_cumulative_energy)

ggsave(file.path(output_dir, "baseline_psd", "aggregated", "baseline_aggregated_psd_tmin_tmax.png"),
       plot_baseline_psd, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)
ggsave(file.path(output_dir, "baseline_psd", "cumulative_energy", "baseline_cumulative_energy_tmin_tmax.png"),
       plot_baseline_cumulative_energy, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 14. DESIGN FIR LOW-PASS AND COMPLEMENTARY HIGH-PASS FILTERS
# ============================================================

# This block designs the windowed-sinc FIR low-pass filter and the complementary
# high-pass filter. It also exports filter coefficients and frequency responses,
# allowing the user to verify that the chosen cutoff frequency and filter order
# produce the intended separation between persistent and fast components.

# Design the FIR filter once and apply the same frequency split to all stations
# and both temperature variables. This ensures comparability across Tmin/Tmax
# and across stations.
fir_coefficients <- make_fir_lowpass_windowed_sinc(
  M = FIR_ORDER_M,
  f_cutoff = FIR_CUTOFF_FREQUENCY,
  window_type = FIR_WINDOW,
  normalize_dc_gain = FIR_NORMALIZE_DC_GAIN
)

FIR_GROUP_DELAY_K <- unique(fir_coefficients$K_group_delay_days)
fir_h <- fir_coefficients$h_lowpass
fir_g <- fir_coefficients$g_highpass_complement

fir_lowpass_response <- compute_fir_frequency_response(fir_h, n_frequency = 2001) %>%
  dplyr::mutate(filter = "Low-pass FIR H(f)")
fir_highpass_response <- compute_fir_frequency_response(fir_g, n_frequency = 2001) %>%
  dplyr::mutate(filter = "Complementary high-pass FIR G(f)")
fir_frequency_response <- dplyr::bind_rows(fir_lowpass_response, fir_highpass_response)

readr::write_csv(fir_coefficients, file.path(output_dir, "dynamic_spectral_decomposition", "fir_filter", "fir_lowpass_and_complementary_highpass_coefficients.csv"))
readr::write_csv(fir_frequency_response, file.path(output_dir, "dynamic_spectral_decomposition", "fir_filter", "fir_frequency_response.csv"))

plot_fir_coefficients <- fir_coefficients %>%
  tidyr::pivot_longer(
    cols = c(h_lowpass, g_highpass_complement),
    names_to = "filter_coefficient",
    values_to = "coefficient"
  ) %>%
  ggplot(aes(x = ell, y = coefficient, linetype = filter_coefficient, shape = filter_coefficient)) +
  geom_hline(yintercept = 0, linewidth = 0.3) +
  geom_line(linewidth = 0.75) +
  geom_point(size = 1.5) +
  labs(
    title = "FIR low-pass and complementary high-pass coefficients",
    subtitle = paste0("M = ", FIR_ORDER_M, ", group delay K = ", FIR_GROUP_DELAY_K, " days, f_c = ", FIR_CUTOFF_FREQUENCY, " cycles/day."),
    x = "Coefficient index ell",
    y = "Coefficient value",
    linetype = "Filter",
    shape = "Filter"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

plot_fir_response <- fir_frequency_response %>%
  ggplot(aes(x = frequency, y = magnitude, linetype = filter)) +
  geom_vline(xintercept = FIR_CUTOFF_FREQUENCY, linetype = "dashed", linewidth = 0.35) +
  geom_line(linewidth = 0.75) +
  labs(
    title = "Frequency response of the FIR filters",
    subtitle = "The high-pass residual is defined by g_ell = delta_{ell,K} - h_ell.",
    x = "Frequency [cycles/day]",
    y = "Magnitude",
    linetype = "Filter"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

print(plot_fir_coefficients)
print(plot_fir_response)

ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "fir_filter", "fir_coefficients.png"),
       plot_fir_coefficients, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)
ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "fir_filter", "fir_frequency_response.png"),
       plot_fir_response, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 15. GROUP-DELAY-ALIGNED DYNAMIC-SPECTRAL DECOMPOSITION
# ============================================================

# This block applies the FIR filters to each station-level centered error series.
# The static bias alpha_s is removed first. Then the residual dynamic component
# is split into a low-pass component and a high-pass residual after correcting
# the FIR group delay.

# Apply the decomposition station by station. The output remains in wide format
# so that the centered error, low-pass component and high-pass residual can be
# compared directly at each aligned date.
error_decomposition_wide <- error_long_complete %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::group_modify(~ compute_group_delay_aligned_decomposition(
    .x,
    h = fir_h,
    g = fir_g,
    K = FIR_GROUP_DELAY_K
  )) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, station, date)

station_static_bias_alpha <- error_decomposition_wide %>%
  dplyr::group_by(temperature_type, station) %>%
  dplyr::summarise(
    alpha_static = dplyr::first(alpha_static),
    n_eff = dplyr::first(n_eff),
    n_total = dplyr::first(n_total),
    n_missing = dplyr::first(n_missing),
    missing_share = dplyr::first(missing_share),
    .groups = "drop"
  ) %>%
  dplyr::arrange(temperature_type, station)

# Verify the core decomposition identity numerically. The maximum and mean
# absolute identity errors should be close to floating-point precision if the
# group-delay alignment has been implemented correctly.
alignment_identity_check <- error_decomposition_wide %>%
  dplyr::filter(valid_group_delay_alignment) %>%
  dplyr::group_by(temperature_type) %>%
  dplyr::summarise(
    n_valid_aligned_points = dplyr::n(),
    max_abs_identity_error = max(abs(identity_error), na.rm = TRUE),
    mean_abs_identity_error = mean(abs(identity_error), na.rm = TRUE),
    group_delay_days = FIR_GROUP_DELAY_K,
    .groups = "drop"
  )

cat("\nGroup-delay alignment identity check:\n")
print(alignment_identity_check)

error_decomposition_long <- error_decomposition_wide %>%
  dplyr::select(
    temperature_type, station, date, center_index, causal_output_index, causal_output_date,
    alpha_static, valid_group_delay_alignment,
    centered_error, lowpass_component, highpass_residual
  ) %>%
  tidyr::pivot_longer(
    cols = c(centered_error, lowpass_component, highpass_residual),
    names_to = "component",
    values_to = "component_value"
  ) %>%
  dplyr::mutate(
    component_label = component_label_from_code(component),
    component = factor(component, levels = c("centered_error", "lowpass_component", "highpass_residual")),
    component_label = factor(component_label, levels = c("Centered error", "Low-pass component", "High-pass residual"))
  ) %>%
  dplyr::arrange(temperature_type, component, station, date)

error_decomposition_long_analysis <- error_decomposition_long %>%
  dplyr::filter(valid_group_delay_alignment, is.finite(component_value))

readr::write_csv(station_static_bias_alpha, file.path(output_dir, "dynamic_spectral_decomposition", "series", "station_static_bias_alpha.csv"))
readr::write_csv(error_decomposition_wide, file.path(output_dir, "dynamic_spectral_decomposition", "series", "error_decomposition_wide_group_delay_aligned.csv"))
readr::write_csv(error_decomposition_long, file.path(output_dir, "dynamic_spectral_decomposition", "series", "error_decomposition_long_group_delay_aligned.csv"))
readr::write_csv(alignment_identity_check, file.path(output_dir, "dynamic_spectral_decomposition", "series", "alignment_identity_check.csv"))


# ============================================================
# 16. ACF OF DECOMPOSED COMPONENTS
# ============================================================

# This block recomputes ACF diagnostics on the centered error, the low-pass
# component and the high-pass residual. The expected qualitative result is that
# the low-pass component preserves long memory, whereas the high-pass residual
# should show reduced persistence.

acf_decomposition_all_stations <- error_decomposition_long_analysis %>%
  dplyr::transmute(
    temperature_type, station, component, component_label, date,
    value = component_value
  ) %>%
  dplyr::group_by(temperature_type, station, component, component_label) %>%
  dplyr::group_modify(~ compute_acf_from_df(.x, value_col = "value", max_lag = max_lag, include_lag0 = include_lag0)) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, component, station, lag)

acf_decomposition_mean <- acf_decomposition_all_stations %>%
  dplyr::group_by(temperature_type, component, component_label, lag) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station[!is.na(acf)]),
    mean_acf = mean(acf, na.rm = TRUE),
    median_acf = median(acf, na.rm = TRUE),
    sd_acf = safe_sd(acf),
    se_acf = ifelse(n_stations > 1, sd_acf / sqrt(n_stations), NA_real_),
    q05_acf = stats::quantile(acf, probs = 0.05, na.rm = TRUE),
    q25_acf = stats::quantile(acf, probs = 0.25, na.rm = TRUE),
    q75_acf = stats::quantile(acf, probs = 0.75, na.rm = TRUE),
    q95_acf = stats::quantile(acf, probs = 0.95, na.rm = TRUE),
    lower_mean_95 = mean_acf - 1.96 * se_acf,
    upper_mean_95 = mean_acf + 1.96 * se_acf,
    .groups = "drop"
  ) %>%
  dplyr::arrange(temperature_type, component, lag)

acf_decomposition_memory_by_station <- acf_decomposition_all_stations %>%
  dplyr::group_by(temperature_type, station, component, component_label) %>%
  dplyr::group_modify(~ summarise_acf_memory(
    .x,
    value_col = "acf",
    threshold = ACF_MEMORY_THRESHOLD,
    consecutive = ACF_MEMORY_CONSECUTIVE_LAGS,
    conf_col = "conf_limit"
  )) %>%
  dplyr::ungroup()

acf_decomposition_memory_summary <- acf_decomposition_memory_by_station %>%
  dplyr::group_by(temperature_type, component, component_label) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station),
    mean_last_lag_abs_above_threshold = mean(last_lag_abs_above_threshold, na.rm = TRUE),
    median_last_lag_abs_above_threshold = median(last_lag_abs_above_threshold, na.rm = TRUE),
    mean_first_lag_below_threshold = mean(first_lag_abs_below_threshold_for_consecutive_lags, na.rm = TRUE),
    median_first_lag_below_threshold = median(first_lag_abs_below_threshold_for_consecutive_lags, na.rm = TRUE),
    mean_first_lag_inside_confidence_band = mean(first_lag_inside_confidence_band_for_consecutive_lags, na.rm = TRUE),
    median_first_lag_inside_confidence_band = median(first_lag_inside_confidence_band_for_consecutive_lags, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(acf_decomposition_all_stations, file.path(output_dir, "dynamic_spectral_decomposition", "acf", "acf_decomposition_all_stations.csv"))
readr::write_csv(acf_decomposition_mean, file.path(output_dir, "dynamic_spectral_decomposition", "acf", "acf_decomposition_mean.csv"))
readr::write_csv(acf_decomposition_memory_by_station, file.path(output_dir, "dynamic_spectral_decomposition", "acf", "acf_decomposition_memory_by_station.csv"))
readr::write_csv(acf_decomposition_memory_summary, file.path(output_dir, "dynamic_spectral_decomposition", "acf", "acf_decomposition_memory_summary.csv"))

plot_decomposition_mean_acf <- ggplot(
  acf_decomposition_mean,
  aes(x = lag, y = mean_acf, linetype = component_label, shape = component_label, group = component_label)
) +
  geom_hline(yintercept = 0, linewidth = 0.35) +
  geom_line(linewidth = 0.75) +
  geom_point(size = 1.1) +
  facet_wrap(~ temperature_type, ncol = 1) +
  labs(
    title = "Mean ACF of group-delay-aligned dynamic-spectral components",
    subtitle = "The low-pass component should retain longer memory; the high-pass residual should display reduced autocorrelation.",
    x = "Lag [days]",
    y = "Mean ACF across stations",
    linetype = "Component",
    shape = "Component"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

plot_decomposition_iqr_acf <- ggplot(
  acf_decomposition_mean,
  aes(x = lag, y = median_acf, linetype = component_label, group = component_label)
) +
  geom_hline(yintercept = 0, linewidth = 0.35) +
  geom_ribbon(aes(ymin = q25_acf, ymax = q75_acf, fill = component_label), alpha = 0.12, linewidth = 0) +
  geom_line(linewidth = 0.75) +
  facet_wrap(~ temperature_type, ncol = 1) +
  labs(
    title = "Median ACF and interquartile station band of decomposed components",
    subtitle = "The ribbon measures cross-station heterogeneity in temporal memory.",
    x = "Lag [days]",
    y = "Median ACF across stations",
    linetype = "Component",
    fill = "Component"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

print(plot_decomposition_mean_acf)
print(plot_decomposition_iqr_acf)

ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "acf", "mean_acf_decomposed_components.png"),
       plot_decomposition_mean_acf, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)
ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "acf", "median_iqr_acf_decomposed_components.png"),
       plot_decomposition_iqr_acf, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 17. PSD OF DECOMPOSED COMPONENTS
# ============================================================

# This block recomputes PSD diagnostics after decomposition. The aim is to verify
# spectrally that the low-pass component concentrates power below the critical
# frequency and that the high-pass residual shifts power toward higher
# frequencies.

psd_decomposition_all_stations <- error_decomposition_long_analysis %>%
  dplyr::transmute(
    temperature_type, station, component, component_label, date,
    value = component_value
  ) %>%
  dplyr::group_by(temperature_type, station, component, component_label) %>%
  dplyr::group_modify(~ compute_psd_from_df(
    .x,
    value_col = "value",
    sampling_interval_days = PSD_SAMPLING_INTERVAL_DAYS,
    remove_mean = PSD_REMOVE_MEAN_DECOMPOSITION,
    remove_linear_trend = PSD_REMOVE_LINEAR_TREND_DECOMPOSITION,
    window_type = PSD_WINDOW
  )) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, component, station, frequency)

psd_decomposition_aggregated <- psd_decomposition_all_stations %>%
  dplyr::group_by(temperature_type, component, component_label, frequency) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station[!is.na(psd)]),
    mean_psd = mean(psd, na.rm = TRUE),
    median_psd = median(psd, na.rm = TRUE),
    sd_psd = safe_sd(psd),
    se_psd = ifelse(n_stations > 1, sd_psd / sqrt(n_stations), NA_real_),
    q05_psd = stats::quantile(psd, probs = 0.05, na.rm = TRUE),
    q25_psd = stats::quantile(psd, probs = 0.25, na.rm = TRUE),
    q75_psd = stats::quantile(psd, probs = 0.75, na.rm = TRUE),
    q95_psd = stats::quantile(psd, probs = 0.95, na.rm = TRUE),
    df_frequency = dplyr::first(df_frequency),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    period_days = ifelse(frequency > 0, 1 / frequency, Inf),
    lower_mean_95 = mean_psd - 1.96 * se_psd,
    upper_mean_95 = mean_psd + 1.96 * se_psd
  ) %>%
  dplyr::arrange(temperature_type, component, frequency)

psd_decomposition_cumulative_energy <- psd_decomposition_aggregated %>%
  dplyr::group_by(temperature_type, component, component_label) %>%
  dplyr::group_modify(~ add_cumulative_energy(.x, psd_col = "mean_psd")) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, component, frequency)

readr::write_csv(psd_decomposition_all_stations, file.path(output_dir, "dynamic_spectral_decomposition", "psd", "psd_decomposition_all_stations.csv"))
readr::write_csv(psd_decomposition_aggregated, file.path(output_dir, "dynamic_spectral_decomposition", "psd", "psd_decomposition_aggregated.csv"))
readr::write_csv(psd_decomposition_cumulative_energy, file.path(output_dir, "dynamic_spectral_decomposition", "psd", "psd_decomposition_cumulative_energy.csv"))

plot_decomposition_psd <- ggplot(
  psd_decomposition_aggregated %>% dplyr::filter(frequency > 0, mean_psd > 0),
  aes(x = frequency, y = mean_psd, linetype = component_label, group = component_label)
) +
  geom_vline(xintercept = FIR_CUTOFF_FREQUENCY, linetype = "dashed", linewidth = 0.35) +
  geom_line(linewidth = 0.75) +
  scale_y_log10() +
  facet_wrap(~ temperature_type, ncol = 1) +
  labs(
    title = "Aggregated PSD of group-delay-aligned decomposed components",
    subtitle = "The low-pass PSD should concentrate below f_c; the high-pass residual should be attenuated in the low-frequency band.",
    x = "Frequency [cycles/day]",
    y = "Mean PSD across stations, log scale",
    linetype = "Component"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

plot_decomposition_cumulative_energy <- ggplot(
  psd_decomposition_cumulative_energy,
  aes(x = frequency, y = cumulative_energy_share, linetype = component_label, shape = component_label, group = component_label)
) +
  geom_hline(yintercept = c(0.50, 0.80, 0.90, 0.95), linetype = "dotted", linewidth = 0.3) +
  geom_vline(xintercept = FIR_CUTOFF_FREQUENCY, linetype = "dashed", linewidth = 0.35) +
  geom_line(linewidth = 0.75) +
  geom_point(size = 1.1) +
  coord_cartesian(ylim = c(0, 1)) +
  facet_wrap(~ temperature_type, ncol = 1) +
  labs(
    title = "Cumulative spectral energy of decomposed components",
    subtitle = "Energy redistribution after group-delay-corrected low-pass/high-pass decomposition.",
    x = "Frequency [cycles/day]",
    y = "Cumulative spectral-energy share",
    linetype = "Component",
    shape = "Component"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

print(plot_decomposition_psd)
print(plot_decomposition_cumulative_energy)

ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "psd", "aggregated_psd_decomposed_components.png"),
       plot_decomposition_psd, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)
ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "psd", "cumulative_energy_decomposed_components.png"),
       plot_decomposition_cumulative_energy, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 18. SPECTRAL FEATURES OF DECOMPOSED COMPONENTS
# ============================================================

# This block converts each PSD into compact numerical descriptors. These
# features are useful for comparing Tmin and Tmax, comparing components, and
# reporting the effectiveness of the dynamic-spectral decomposition.

spectral_features_decomposition_aggregated <- psd_decomposition_aggregated %>%
  dplyr::group_by(temperature_type, component, component_label) %>%
  dplyr::group_modify(~ compute_spectral_features_from_psd(
    .x,
    psd_col = "mean_psd",
    f_critical = PSD_CRITICAL_FREQUENCY,
    dominant_exclude_zero = PSD_DOMINANT_EXCLUDE_ZERO
  )) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(level = "aggregated") %>%
  dplyr::arrange(temperature_type, component)

spectral_features_decomposition_by_station <- psd_decomposition_all_stations %>%
  dplyr::group_by(temperature_type, station, component, component_label) %>%
  dplyr::group_modify(~ compute_spectral_features_from_psd(
    .x,
    psd_col = "psd",
    f_critical = PSD_CRITICAL_FREQUENCY,
    dominant_exclude_zero = PSD_DOMINANT_EXCLUDE_ZERO
  )) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(level = "station") %>%
  dplyr::arrange(temperature_type, station, component)

spectral_features_decomposition_by_station_summary <- spectral_features_decomposition_by_station %>%
  dplyr::group_by(temperature_type, component, component_label) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station),
    mean_R_low = mean(R_low, na.rm = TRUE),
    median_R_low = median(R_low, na.rm = TRUE),
    mean_low_high_ratio = mean(low_high_ratio, na.rm = TRUE),
    median_low_high_ratio = median(low_high_ratio, na.rm = TRUE),
    mean_dominant_frequency = mean(dominant_frequency, na.rm = TRUE),
    median_dominant_frequency = median(dominant_frequency, na.rm = TRUE),
    mean_spectral_centroid = mean(spectral_centroid, na.rm = TRUE),
    median_spectral_centroid = median(spectral_centroid, na.rm = TRUE),
    mean_spectral_entropy_normalized = mean(spectral_entropy_normalized, na.rm = TRUE),
    median_spectral_entropy_normalized = median(spectral_entropy_normalized, na.rm = TRUE),
    .groups = "drop"
  )

readr::write_csv(spectral_features_decomposition_aggregated, file.path(output_dir, "dynamic_spectral_decomposition", "spectral_features", "spectral_features_decomposition_aggregated.csv"))
readr::write_csv(spectral_features_decomposition_by_station, file.path(output_dir, "dynamic_spectral_decomposition", "spectral_features", "spectral_features_decomposition_by_station.csv"))
readr::write_csv(spectral_features_decomposition_by_station_summary, file.path(output_dir, "dynamic_spectral_decomposition", "spectral_features", "spectral_features_decomposition_by_station_summary.csv"))

plot_R_low_decomposition <- ggplot(
  spectral_features_decomposition_aggregated,
  aes(x = component_label, y = R_low, fill = temperature_type)
) +
  geom_col(position = "dodge") +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    title = "Low-frequency energy share of decomposed components",
    subtitle = paste0("Low band: f <= ", PSD_CRITICAL_FREQUENCY, " cycles/day. High band: f > ", PSD_CRITICAL_FREQUENCY, " cycles/day."),
    x = "Component",
    y = "R_low = E_low / (E_low + E_high)",
    fill = "Temperature type"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

plot_centroid_entropy_decomposition <- spectral_features_decomposition_aggregated %>%
  dplyr::select(temperature_type, component_label, spectral_centroid, spectral_entropy_normalized) %>%
  tidyr::pivot_longer(
    cols = c(spectral_centroid, spectral_entropy_normalized),
    names_to = "feature",
    values_to = "value"
  ) %>%
  ggplot(aes(x = component_label, y = value, fill = temperature_type)) +
  geom_col(position = "dodge") +
  facet_wrap(~ feature, scales = "free_y") +
  labs(
    title = "Spectral centroid and normalized spectral entropy",
    subtitle = "The high-pass residual should generally shift toward higher centroid values after correction.",
    x = "Component",
    y = "Feature value",
    fill = "Temperature type"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

print(plot_R_low_decomposition)
print(plot_centroid_entropy_decomposition)

ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "spectral_features", "R_low_decomposed_components.png"),
       plot_R_low_decomposition, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)
ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "spectral_features", "centroid_entropy_decomposed_components.png"),
       plot_centroid_entropy_decomposition, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 19. LJUNG-BOX BEFORE/AFTER FILTERING
# ============================================================

# This block compares the centered error before filtering with the high-pass
# residual after filtering. If the filtering step successfully removes persistent
# dynamics, the share of stations that do not reject the null hypothesis of no
# autocorrelation should increase.

# Compare serial dependence before and after removing the low-frequency
# component. The "before" series is the centered error, while the "after" series
# is the high-pass residual.
ljung_box_before_after <- error_decomposition_wide %>%
  dplyr::filter(valid_group_delay_alignment) %>%
  dplyr::select(temperature_type, station, date, centered_error, highpass_residual) %>%
  tidyr::pivot_longer(
    cols = c(centered_error, highpass_residual),
    names_to = "series_type",
    values_to = "value"
  ) %>%
  dplyr::mutate(
    series_label = dplyr::case_when(
      series_type == "centered_error" ~ "Before filtering: centered error",
      series_type == "highpass_residual" ~ "After filtering: high-pass residual",
      TRUE ~ series_type
    ),
    series_label = factor(
      series_label,
      levels = c("Before filtering: centered error", "After filtering: high-pass residual")
    )
  ) %>%
  dplyr::group_by(temperature_type, station, series_type, series_label) %>%
  dplyr::group_modify(~ compute_ljung_box_vector(
    .x$value,
    lags = LJUNG_BOX_LAGS,
    alpha = LJUNG_BOX_ALPHA,
    fitdf = LJUNG_BOX_FITDF
  )) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(temperature_type, ljung_box_lag, station, series_type)

ljung_box_summary <- ljung_box_before_after %>%
  dplyr::group_by(temperature_type, series_type, series_label, ljung_box_lag) %>%
  dplyr::summarise(
    n_stations = dplyr::n_distinct(station),
    n_non_reject_H0 = sum(do_not_reject_H0_no_autocorrelation, na.rm = TRUE),
    share_non_reject_H0 = n_non_reject_H0 / n_stations,
    n_reject_H0 = sum(reject_H0_autocorrelation_absent, na.rm = TRUE),
    share_reject_H0 = n_reject_H0 / n_stations,
    median_p_value = median(p_value, na.rm = TRUE),
    mean_p_value = mean(p_value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(temperature_type, ljung_box_lag, series_type)

readr::write_csv(ljung_box_before_after, file.path(output_dir, "dynamic_spectral_decomposition", "ljung_box", "ljung_box_before_after_by_station.csv"))
readr::write_csv(ljung_box_summary, file.path(output_dir, "dynamic_spectral_decomposition", "ljung_box", "ljung_box_before_after_summary.csv"))

plot_ljung_box_summary <- ggplot(
  ljung_box_summary,
  aes(x = factor(ljung_box_lag), y = share_non_reject_H0, fill = series_label)
) +
  geom_col(position = "dodge") +
  facet_wrap(~ temperature_type, ncol = 1) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    title = "Ljung-Box diagnostic before and after filtering",
    subtitle = paste0("Share of stations for which H0 is not rejected at alpha = ", LJUNG_BOX_ALPHA, ". H0: no autocorrelation up to the tested lag."),
    x = "Ljung-Box lag [days]",
    y = "Share of stations not rejecting H0",
    fill = "Series"
  ) +
  theme_bw() +
  theme(legend.position = "bottom", plot.title = element_text(size = 13, face = "bold"))

print(plot_ljung_box_summary)

ggsave(file.path(output_dir, "dynamic_spectral_decomposition", "ljung_box", "ljung_box_share_non_reject_H0.png"),
       plot_ljung_box_summary, width = PLOT_WIDTH, height = PLOT_HEIGHT, dpi = PLOT_DPI)


# ============================================================
# 20. FINAL OBJECT EXPORT
# ============================================================

# This final block stores the main intermediate and final objects in one RDS file.
# The RDS archive makes the analysis reproducible without re-reading the Excel
# file or recomputing all diagnostics, while the CSV outputs remain convenient
# for inspection and external reporting.

analysis_objects <- list(
  parameters = list(
    error_convention = "observed - forecast",
    max_lag = max_lag,
    PSD_CRITICAL_FREQUENCY = PSD_CRITICAL_FREQUENCY,
    PSD_CRITICAL_PERIOD_DAYS = PSD_CRITICAL_PERIOD_DAYS,
    FIR_ORDER_M = FIR_ORDER_M,
    FIR_GROUP_DELAY_K = FIR_GROUP_DELAY_K,
    FIR_CUTOFF_FREQUENCY = FIR_CUTOFF_FREQUENCY,
    FIR_WINDOW = FIR_WINDOW,
    LJUNG_BOX_LAGS = LJUNG_BOX_LAGS,
    LJUNG_BOX_ALPHA = LJUNG_BOX_ALPHA
  ),
  data_clean = data_clean,
  error_long_complete = error_long_complete,
  baseline_acf_all_stations = baseline_acf_all_stations,
  baseline_acf_mean = baseline_acf_mean,
  baseline_psd_all_stations = baseline_psd_all_stations,
  baseline_psd_aggregated = baseline_psd_aggregated,
  baseline_psd_cumulative_energy = baseline_psd_cumulative_energy,
  baseline_spectral_features_aggregated = baseline_spectral_features_aggregated,
  baseline_spectral_features_by_station = baseline_spectral_features_by_station,
  fir_coefficients = fir_coefficients,
  fir_frequency_response = fir_frequency_response,
  error_decomposition_wide = error_decomposition_wide,
  error_decomposition_long = error_decomposition_long,
  alignment_identity_check = alignment_identity_check,
  acf_decomposition_all_stations = acf_decomposition_all_stations,
  acf_decomposition_mean = acf_decomposition_mean,
  psd_decomposition_all_stations = psd_decomposition_all_stations,
  psd_decomposition_aggregated = psd_decomposition_aggregated,
  psd_decomposition_cumulative_energy = psd_decomposition_cumulative_energy,
  spectral_features_decomposition_aggregated = spectral_features_decomposition_aggregated,
  spectral_features_decomposition_by_station = spectral_features_decomposition_by_station,
  ljung_box_before_after = ljung_box_before_after,
  ljung_box_summary = ljung_box_summary
)

saveRDS(
  analysis_objects,
  file.path(output_dir, "dynamic_spectral_error_analysis_objects.rds")
)

readr::write_lines(
  capture.output(utils::sessionInfo()),
  file.path(output_dir, "diagnostics", "session_info.txt")
)

cat("\n============================================================\n")
cat("PIPELINE COMPLETED SUCCESSFULLY\n")
cat("============================================================\n")
cat("Main output directory:\n")
cat(output_dir, "\n\n")
cat("Key outputs:\n")
cat("- series/error_long_complete_station_date_grid.csv\n")
cat("- baseline_acf/baseline_acf_mean_across_stations.csv\n")
cat("- baseline_psd/aggregated/baseline_psd_aggregated.csv\n")
cat("- baseline_psd/spectral_features/baseline_spectral_features_aggregated.csv\n")
cat("- dynamic_spectral_decomposition/fir_filter/fir_lowpass_and_complementary_highpass_coefficients.csv\n")
cat("- dynamic_spectral_decomposition/series/error_decomposition_wide_group_delay_aligned.csv\n")
cat("- dynamic_spectral_decomposition/series/alignment_identity_check.csv\n")
cat("- dynamic_spectral_decomposition/acf/acf_decomposition_mean.csv\n")
cat("- dynamic_spectral_decomposition/psd/psd_decomposition_aggregated.csv\n")
cat("- dynamic_spectral_decomposition/spectral_features/spectral_features_decomposition_aggregated.csv\n")
cat("- dynamic_spectral_decomposition/ljung_box/ljung_box_before_after_summary.csv\n")
cat("\nInterpretive check:\n")
cat("The high-pass residual is group-delay corrected through g_ell = delta_{ell,K} - h_ell.\n")
cat("The decomposition identity should be numerically close to zero in alignment_identity_check.csv.\n")
cat("============================================================\n")
