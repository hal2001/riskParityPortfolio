#' riskParityPortfolio: Design of Risk Parity Portfolios
#'
#' Fast design of risk-parity portfolios for financial investment.
#' The goal of the risk-parity portfolio formulation is to equalize or distribute
#' the risk contributions of the different assets, which is missing if we simply
#' consider the overall volatility of the portfolio as in the mean-variance
#' Markowitz portfolio. In addition to the vanilla formulation, where the risk
#' contributions are perfectly equalized subject to no shortselling and budget
#' constraints, many other formulations are considered that allow for box
#' constraints and shortselling, as well as the inclusion of additional
#' objectives like the expected return and overall variance. See vignette for
#' a detailed documentation and comparison, with several illustrative examples.
#'
#' @section Functions:
#' \code{\link{riskParityPortfolio}}
#'
#' @section Help:
#' For a quick help see the README file:
#' \href{https://github.com/dppalomar/riskParityPortfolio}{GitHub-README}.
#'
#' For more details see the vignette:
#' \href{https://session.run/riskParityPortfolio/_static/getting_started.html}{GitHub-html-vignette}.
#'
#' @author Ze Vinicius and Daniel P. Palomar
#'
#' @references
#' Y. Feng, and D. P. Palomar, "SCRIP: Successive Convex Optimization Methods
#' for Risk Parity Portfolio Design," \emph{IEEE Trans. on Signal Processing},
#' vol. 63, no. 19, pp. 5285-5300, Oct. 2015. (https://doi.org/10.1109/TSP.2015.2452219)
#'
#' F. Spinu, "An Algorithm for Computing Risk Parity Weights" (July 30, 2013).
#' Available at SSRN: https://ssrn.com/abstract=2297383 or http://dx.doi.org/10.2139/ssrn.2297383
#'
#' @importFrom Rcpp sourceCpp
#' @useDynLib riskParityPortfolio
#' @docType package
#' @name riskParityPortfolio-package
NULL
