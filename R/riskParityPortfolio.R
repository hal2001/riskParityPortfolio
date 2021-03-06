# @title Risk parity portfolio design for uncorrelated assets
#
# @description Risk parity portfolio optimization for the case of diagonal Sigma
# that satisfies the constraints sum(w) = 1 and w >= 0.
#
# @param Sigma covariance or correlation matrix
# @param b budget vector
# @return a list containing the following elements:
# \item{\code{w}}{optimal portfolio vector}
# \item{\code{risk_contribution}}{the risk contribution of every asset}
#
# @author Daniel Palomar and Ze Vinicius
riskParityPortfolioDiagSigma <- function(Sigma, b = rep(1/nrow(Sigma), nrow(Sigma))) {
  w <- sqrt(b) / sqrt(diag(Sigma))
  w <- w / sum(w)
  return (list(w = w, risk_contribution = as.vector(w * (Sigma %*% w))))
}


# @title Fast risk parity portfolio design using successive convex
#        approximation and a quadratic programming solver
#
# @description Risk parity portfolio optimization using successive convex
#              approximation (SCA) to cast the optimization problem into a
#              series of QP problems fastly solvable using quadprog::solve.QP.
#
# @param Sigma covariance or correlation matrix
# @param b budget vector, aka, risk budgeting targets
# @param mu vector of expected returns
# @param lmd_mu scalar that controls the importance of the expected return term
# @param lmd_var scalar that controls the importance of the variance term
# @param budget boolean indicating whether to consider sum(w) = 1 as a
#        constraint
# @param shortselling boolean indicating whether to allow short-selling, i.e.,
#        w < 0
# @param formulation string indicating the formulation to be used for the risk
#        parity optimization problem. It must be one of: "rc-double-index",
#        "rc-over-b-double-index", "rc-over-var vs b", "rc-over-var",
#        "rc-over-sd vs b-times-sd", "rc vs b-times-var", "rc vs theta", or
#        "rc-over-b vs theta".
# @param w0 initial value for the portfolio wieghts. Default is the optimum
#        portfolio weights for the case when Sigma is diagonal.
# @param theta0 initial value for theta. If NULL, the optimum solution for a fixed
#        vector of portfolio weights will be used.
# @param gamma learning rate
# @param zeta factor used to decrease the learning rate at each iteration
# @param tau regularization factor. If NULL, a meaningful value will be used
# @param maxiter maximum number of iterations for the SCA loop
# @param ftol convergence tolerance on the value of the objective function
# @param wtol convergence tolerance on the values of the parameters
# @return a list containing the following elements:
# \item{\code{w}}{optimal portfolio vector}
# \item{\code{theta}}{the optimal value for theta (in case that it is part of the chosen formulation}
# \item{\code{obj_fun}}{the sequence of values from the objective function at each iteration}
# \item{\code{elapsed_time}}{elapsed time recorded at every iteration}
# \item{\code{convergence}}{flag to indicate whether or not the optimization converged.
# The value `1` means it has converged, and `0` otherwise.}
# \item{\code{risk_contribution}}{the risk contribution of every asset}
#
# @author Daniel Palomar and Ze Vinicius
riskParityPortfolioSCA <- function(Sigma, b = rep(1/nrow(Sigma), nrow(Sigma)),
                                   mu = NULL, lmd_mu = 1e-4, lmd_var = 0,
                                   budget = TRUE, shortselling = FALSE,
                                   formulation = c("rc-double-index",
                                                   "rc-over-b-double-index",
                                                   "rc-over-var vs b",
                                                   "rc-over-var",
                                                   "rc-over-sd vs b-times-sd",
                                                   "rc vs b-times-var",
                                                   "rc vs theta",
                                                   "rc-over-b vs theta"),
                                   w0 = NULL, theta0 = NULL, gamma = .9, zeta = 1e-7,
                                   tau = NULL, maxiter = 500, ftol = 1e-6, wtol = 1e-6) {
  has_var <- lmd_var > 0
  N <- nrow(Sigma)
  if (is.null(w0))
    w0 <- riskParityPortfolioDiagSigma(Sigma, b)$w

  formulation <- match.arg(formulation)
  has_theta <- grepl("theta", formulation)
  if (has_theta) {
    if (is.null(theta0))
      theta0 <- mean(w0 * (Sigma %*% w0))
    w0 <- as.vector(c(w0, theta0))
  }

  if (is.null(tau))
    tau <- .05 * sum(diag(Sigma)) / (2*N)

  if (has_theta) {
    ones <- rep(1, N)
    zeros <- rep(0, N+1)
    if (budget && !shortselling) {
      Amat <- cbind(c(ones, 0), diag(c(ones, 0)))
      bvec <- c(1, zeros)
      meq <- 1
    } else if (budget && shortselling) {
      Amat <- rbind(matrix(1, N, 1), 0)
      bvec <- 1
      meq <- 1
    } else if (!budget && !shortselling) {
      Amat <- diag(c(ones, 0))
      bvec <- zeros
      meq <- 0
    } else {
      Amat <- diag(zeros)
      bvec <- zeros
      meq <- 0
    }
  } else {
    zeros <- rep(0, N)
    if (budget && !shortselling) {
      Amat <- cbind(rep(1, N), diag(N))
      bvec <- c(1, zeros)
      meq <- 1
    } else if (budget && shortselling) {
      Amat <- matrix(1, N, 1)
      bvec <- 1
      meq <- 1
    } else if (!budget && !shortselling) {
      Amat <- diag(N)
      bvec <- rep(0, N)
      meq <- 0
    } else {
      Amat <- diag(zeros)
      bvec <- zeros
      meq <- 0
    }
  }

  switch(formulation,
         "rc-double-index" = {
           R <- R_rc_double_index
           g <- g_rc_double_index
           A <- A_rc_double_index
         },
         "rc-over-b-double-index" = {
           R <- R_rc_over_b_double_index
           g <- g_rc_over_b_double_index
           A <- A_rc_over_b_double_index
         },
         "rc-over-var vs b" = {
           R <- R_rc_over_var_vs_b
           g <- g_rc_over_var_vs_b
           A <- A_rc_over_var_vs_b
         },
         "rc-over-var" = {
           R <- R_rc_over_var
           g <- g_rc_over_var
           A <- A_rc_over_var
         },
         "rc-over-sd vs b-times-sd" = {
           R <- R_rc_over_sd_vs_b_times_sd
           g <- g_rc_over_sd_vs_b_times_sd
           A <- A_rc_over_sd_vs_b_times_sd
         },
         "rc vs b-times-var"  = {
           R <- R_rc_vs_b_times_var
           g <- g_rc_vs_b_times_var
           A <- A_rc_vs_b_times_var
         },
         "rc vs theta" = {
           R <- R_rc_vs_theta
           g <- g_rc_vs_theta
           A <- A_rc_vs_theta
         },
         "rc-over-b vs theta" = {
           R <- R_rc_over_b_vs_theta
           g <- g_rc_over_b_vs_theta
           A <- A_rc_over_b_vs_theta
         },
         stop("formulation ", formulation, " is not included.")
  )

  has_mu <- !is.null(mu)
  # compute and store objective function at the initial value
  wk <- w0
  fun_k <- R(wk, Sigma, b)
  if (has_mu) {
    if (has_theta)
      fun_k <- fun_k - lmd_mu * t(mu) %*% wk[1:N]
    else
      fun_k <- fun_k - lmd_mu * t(mu) %*% wk
  }
  fun_seq <- c(fun_k)
  time_seq <- c(0)

  if (has_theta)
    tauI <- diag(rep(tau, N + 1))
  else
    tauI <- diag(rep(tau, N))

  start_time <- proc.time()[3]
  for (k in 1:maxiter) {
    # auxiliary quantities
    if (has_theta) {
      Sigma_wk <- Sigma %*% wk[1:N]
      rk <- wk[1:N] * Sigma_wk
    } else {
      Sigma_wk <- Sigma %*% wk
      rk <- wk * Sigma_wk
    }
    Ak <- A(wk, Sigma, b, Sigma_w = Sigma_wk)
    g_wk <- g(wk, Sigma, b, r = rk)
    Qk <- 2 * crossprod(Ak) + tauI
    if (has_var)
      Qk <- Qk + lmd_var * Sigma
    qk <- 2 * t(Ak) %*% g_wk - Qk %*% wk
    if (has_mu)
      if (has_theta)
        qk <- qk - lmd_mu * c(mu, 0)
      else
        qk <- qk - lmd_mu * mu
    # build and solve problem (39) as in Feng & Palomar TSP2015
    w_hat <- quadprog::solve.QP(Qk, -qk, Amat = Amat, bvec = bvec,
                                meq = meq)$solution
    w_next <- wk + gamma * (w_hat - wk)
    # save objective function value and elapsed time
    time_seq <- c(time_seq, proc.time()[3] - start_time)
    fun_next <- R(w_next, Sigma, b)
    if (has_mu)
      if (has_theta)
        fun_next <- fun_next - lmd_mu * t(mu) %*% w_next[1:N]
      else
        fun_next <- fun_next - lmd_mu * t(mu) %*% w_next
    fun_seq <- c(fun_seq, fun_next)
    # check convergence on parameters and objective function
    werr <- sum(abs(w_next - wk)) / max(1, sum(abs(wk)))
    ferr <- abs(fun_next - fun_k) / max(1, abs(fun_k))
    if (k > 1 && (werr < wtol || ferr < ftol))
      break
    # update variables
    wk <- w_next
    fun_k <- fun_next
    gamma <- gamma * (1 - zeta * gamma)
  }

  portfolio_results <- list()
  portfolio_results$risk <- fun_seq[length(fun_seq)]
  if (!has_theta) {
    portfolio_results$w <- w_next
    portfolio_results$risk_contribution <- as.vector(w_next * (Sigma %*% w_next))
  } else {
    portfolio_results$w <- w_next[1:N]
    portfolio_results$theta <- w_next[N+1]
    portfolio_results$risk_contribution <- as.vector(w_next[1:N] * (Sigma %*% w_next[1:N]))
  }
  if (has_mu) {
    portfolio_results$mean_return <- t(mu) %*% portfolio_results$w
    portfolio_results$risk <- portfolio_results$risk + lmd_mu * portfolio_results$mean_return
  }
  if (has_var) {
    portfolio_results$variance <- t(portfolio_results$w) %*% Sigma %*% portfolio_results$w
    portfolio_results$risk <- portfolio_results$risk - lmd_var * portfolio_results$variance
  }
  portfolio_results$obj_fun <- fun_seq
  portfolio_results$elapsed_time <- time_seq
  portfolio_results$convergence <- sum(!(k == maxiter))
  return(portfolio_results)
}


# @title Risk parity portfolio design using general constrained solvers
#
# @description Risk parity portfolio optimization using general purpose
#              constrained solvers from the alabama and nloptr packages
#
# @param Sigma covariance or correlation matrix
# @param b budget vector, aka, risk budgeting targets
# @param mu vector of expected returns
# @param lmd_mu scalar that controls the importance of the expected return term
# @param lmd_var scalar that controls the importance of the variance term
# @param budget boolean indicating whether to consider sum(w) = 1 as a
#        constraint
# @param shortselling boolean indicating whether to allow short-selling, i.e.,
#        w < 0
# @param formulation string indicating the formulation to be used for the risk
#        parity optimization problem. It must be one of: "rc-double-index",
#        "rc-over-b-double-index", "rc-over-var vs b", "rc-over-var",
#        "rc-over-sd vs b-times-sd", "rc vs b-times-var", "rc vs theta", or
#        "rc-over-b vs theta"
# @param method which solver to use. It must be one of: "slsqp" or "alabama"
# @param use_gradient if TRUE, gradients of the objective function wrt to the
#        parameters will be used. This is strongly recommended to achive faster
#        results
# @param w0 initial value for the portfolio wieghts. Default is the optimum
#        portfolio weights for the case when Sigma is diagonal
# @param theta0 initial value for theta. If NULL, the optimum solution for a fixed
#        vector of portfolio weights will be used
# @param gamma learning rate
# @param zeta factor used to decrease the learning rate at each iteration
# @param tau regularization factor. If NULL, a meaningful value will be used
# @param maxiter maximum number of iterations for the outer loop of the solver
# @param ftol convergence tolerance on the value of the objective function
# @param wtol convergence tolerance on the values of the parameters
# @return a list containing the following elements:
# \item{\code{w}}{optimal portfolio vector}
# \item{\code{theta}}{the optimal value for theta (in case that it is part of the chosen formulation}
# \item{\code{obj_fun}}{the sequence of values from the objective function at each iteration}
# \item{\code{elapsed_time}}{elapsed time recorded at every iteration}
# \item{\code{convergence}}{flag to indicate whether or not the optimization converged.
# The value `1` means it has converged, and `0` otherwise.}
# \item{\code{risk_contribution}}{the risk contribution of every asset}
#
# @author Daniel Palomar and Ze Vinicius
riskParityPortfolioGenSolver <- function(Sigma, b = NULL, mu = NULL, lmd_mu = 1e-4,
                                         budget = TRUE, shortselling = FALSE,
                                         formulation = c("rc-double-index",
                                                         "rc-over-b-double-index",
                                                         "rc-over-var vs b",
                                                         "rc-over-var",
                                                         "rc-over-sd vs b-times-sd",
                                                         "rc vs b-times-var",
                                                         "rc vs theta",
                                                         "rc-over-b vs theta"),
                                         method = c("slsqp", "alabama"),
                                         use_gradient = TRUE, w0 = NULL, theta0 = NULL,
                                         maxiter = 500, ftol = 1e-6, wtol = 1e-6) {
  N <- nrow(Sigma)
  if (is.null(b))
    b <- rep(1/N, N)
  if (is.null(w0))
    w0 <- riskParityPortfolioDiagSigma(Sigma, b)$w

  formulation <- match.arg(formulation)
  # set initial value for theta
  has_theta <- grepl("theta", formulation)
  if (has_theta) {
    if (is.null(theta0)) {
      r0 <- w0 * (Sigma %*% w0)
      theta0 <- mean(r0 / b)
    }
    w0 <- as.vector(c(w0, theta0))
  }
  # set equality constraints
  if (budget) {
    if (has_theta) {
      budget <- function(w, ...) {
        N <- length(w) - 1
        return(sum(w[1:N]) - 1)
      }
      budget.jac <- function(w, ...) {
        N <- length(w) - 1
        return(cbind(matrix(1, 1, N), 0))
      }
    } else {
      budget <- function(w, ...)
        return(sum(w) - 1)
      budget.jac <- function(w, ...) {
        N <- length(w)
        return(matrix(1, 1, N))
      }
    }
  } else {
    budget <- NULL
    budget.jac <- NULL
  }
  # set inequality constraints
  if (!shortselling) {
    if (has_theta) {
      shortselling <- function(w, ...) {
        N <- length(w) - 1
        return(w[1:N])
      }
      shortselling.jac <- function(w, ...) {
        N <- length(w) - 1
        return(cbind(diag(N), rep(0, N)))
      }
    } else {
      shortselling <- function(w, ...)
        return(w)
      shortselling.jac <- function(w, ...)
        return(diag(length(w)))
    }
  } else {
    shortselling <- NULL
    shortselling.jac <- NULL
  }

  switch(formulation,
         "rc-double-index" = {
           R <- R_rc_double_index
           R_grad <- R_grad_rc_double_index
         },
         "rc-over-b-double-index" = {
           R <- R_rc_over_b_double_index
           R_grad <- R_grad_rc_over_b_double_index
         },
         "rc-over-var vs b" = {
           R <- R_rc_over_var_vs_b
           R_grad <- R_grad_rc_over_var_vs_b
         },
         "rc-over-var" = {
           R <- R_rc_over_var
           R_grad <- R_grad_rc_over_var
         },
         "rc-over-sd vs b-times-sd" = {
           R <- R_rc_over_sd_vs_b_times_sd
           R_grad <- R_grad_rc_over_sd_vs_b_times_sd
         },
         "rc vs b-times-var"  = {
           R <- R_rc_vs_b_times_var
           R_grad <- R_grad_rc_vs_b_times_var
         },
         "rc vs theta" = {
           R <- R_rc_vs_theta
           R_grad <- R_grad_rc_vs_theta
         },
         "rc-over-b vs theta" = {
           R <- R_rc_over_b_vs_theta
           R_grad <- R_grad_rc_over_b_vs_theta
         },
         stop("formulation ", formulation, " is not included.")
  )
  if (!use_gradient)
    R_grad <- NULL
  has_mu <- !is.null(mu)
  if (has_mu) {
    wrap_R <- function(R, lmd_mu, mu, has_theta, N) {
      if (has_theta) {
        func <- function(...) {
          kwargs <- list(...)
          w_ <- kwargs[[1]]
          return(R(...) - lmd_mu * t(mu) %*% w_[1:N])
        }
      } else {
        func <- function(...) {
          kwargs <- list(...)
          return(R(...) - lmd_mu * t(mu) %*% kwargs[[1]])
        }
      }
      return(func)
    }
    wrap_R_grad <- function(R_grad, lmd_mu, mu) {
      grad <- function(...) {
        return(R_grad(...) - lmd_mu * mu)
      }
      return(grad)
    }
    R_ <- wrap_R(R, lmd_mu, mu, has_theta, N)
    R_grad_ <- wrap_R_grad(R_grad, lmd_mu, mu)
  } else {
    R_ <- R
    R_grad_ <- R_grad
  }
  fun_seq <- c(R(w0, Sigma, b))
  time_seq <- c(0)
  switch(match.arg(method),
         "alabama" = {
           start_time <- proc.time()[3]
           res <- alabama::constrOptim.nl(w0, R_, R_grad_,
                                          hin = shortselling,
                                          hin.jac = shortselling.jac,
                                          heq = budget,
                                          heq.jac = budget.jac,
                                          Sigma = Sigma, b = b,
                                          control.outer = list(trace = FALSE,
                                                               itmax = maxiter))
           end_time <- proc.time()[3]
         },
         "slsqp" = {
           start_time <- proc.time()[3]
           res <- nloptr::slsqp(w0, R_, R_grad_,
                                hin = shortselling, hinjac = shortselling.jac,
                                heq = budget, heqjac = budget.jac,
                                Sigma = Sigma, b = b,
                                control = list(xtol_rel = wtol, ftol_rel = ftol))
           end_time <- proc.time()[3]
         },
         stop("method ", method, "is not included.")
  )
  # save objective value and elapsed time
  time_seq <- c(time_seq, end_time - start_time)
  fun_seq <- c(fun_seq, res$value)
  w <- res$par

  portfolio_results <- list()
  portfolio_results$risk <- fun_seq[length(fun_seq)]
  if (!has_theta) {
    portfolio_results$w <- w
    portfolio_results$risk_contribution <- as.vector(w * (Sigma %*% w))
  } else {
    portfolio_results$w <- w[1:N]
    portfolio_results$theta <- w[N+1]
    portfolio_results$risk_contribution <- as.vector(w[1:N] * (Sigma %*% w[1:N]))
  }
  if (has_mu) {
    portfolio_results$mean_return <- t(mu) %*% portfolio_results$w
    portfolio_results$risk <- portfolio_results$risk + lmd_mu * portfolio_results$mean_return
  }
  portfolio_results$obj_fun <- fun_seq
  portfolio_results$elapsed_time <- time_seq
  portfolio_results$convergence <- res$convergence
  return(portfolio_results)
}


# @title Fast vanilla risk parity portfolio design using the Newton method
#
# @description Risk parity portfolio optimization using the Newton method
#              proposed by Spinu (2013)
#
# @param Sigma covariance or correlation matrix
# @param b budget vector
# @param maxiter maximum number of iterations of both damped and quadratic phases
# @param tol tolerance of the stopping criteria
# @return a list containing the following elements:
# \item{\code{w}}{optimal portfolio vector}
# \item{\code{risk_contribution}}{the risk contribution of every asset}
riskParityPortfolioNewton <- function(Sigma, b = rep(1/nrow(Sigma), nrow(Sigma)),
                                      maxiter = 50, tol = 1e-6) {
  w <- risk_parity_portfolio_nn(Sigma, b, tol, maxiter)
  return(list(w = w, risk_contribution = c(w * (Sigma %*% w))))
}


# @title Fast vanilla risk parity algorithm for high dimensional portfolio
#        design using the cyclical coordinate descent method.
#
# @description Risk parity portfolio optimization using the cyclical method
#              proposed by Griveau-Billion (2013)
#
# @param Sigma covariance or correlation matrix
# @param b budget vector
# @param maxiter maximum number of iterations of both damped and quadratic phases
# @param tol tolerance of the stopping criteria
# @return a list containing the following elements:
# \item{\code{w}}{optimal portfolio vector}
# \item{\code{risk_contribution}}{the risk contribution of every asset}
riskParityPortfolioCyclical <- function(Sigma, b = rep(1/nrow(Sigma), nrow(Sigma)),
                                        maxiter = 50, tol = 1e-6) {
  w <- risk_parity_portfolio_ccd(Sigma, b, tol, maxiter)
  return(list(w = w, risk_contribution = c(w * (Sigma %*% w))))
}


#' @title Design of Risk Parity Portfolios
#'
#' @description This functions uses the vanilla (Newton or Cyclical) risk parity
#'              portfolio in order to initialize either the SCA method or a
#'              general solver. This convenience function helps to put together
#'              the advantages of both methods.
#'
#' @param Sigma covariance or correlation matrix
#' @param b budget vector, aka, risk budgeting targets
#' @param mu vector of expected returns
#' @param lmd_mu scalar the controls the importance of the expected return term
#' @param lmd_var scalar that controls the importance of the variance term
#'        (only available for the SCA method for now).
#' @param budget boolean indicating whether to consider sum(w) = 1 as a
#'        constraint
#' @param shortselling boolean indicating whether to allow short-selling, i.e.,
#'        w < 0
#' @param method which optimization method to use.
#' @param formulation string indicating the formulation to be used for the risk
#'        parity optimization problem. It must be one of: "diag", "rc-double-index",
#'        "rc-over-b-double-index", "rc-over-var vs b", "rc-over-var",
#'        "rc-over-sd vs b-times-sd", "rc vs b-times-var", "rc vs theta", or
#'        "rc-over-b vs theta". If formulation is NULL and no additional terms
#'        or constraints are set, such as expected return or shortselling, then
#'        the vanilla risk parity portfolio will be returned. If formulation is
#'        "diag" then the analytical solution of the risk parity optimization for
#'        for a diagonal covariance matrix will be returned.
#' @param w0 initial value for the portfolio weights. Default is the vanilla
#'        portfolio computed either with Newton or Cyclical methods.
#' @param theta0 initial value for theta. If NULL, the optimum solution for a fixed
#'        vector of portfolio weights will be used
#' @param gamma learning rate
#' @param zeta factor used to decrease the learning rate at each iteration
#' @param tau regularization factor. If NULL, a meaningful value will be used
#' @param maxiter maximum number of iterations for the SCA loop
#' @param use_gradient (this parameter is meaningful only if method is either
#'        "alabama" or "slsqp") if TRUE, gradients of the objective function wrt to the
#'        parameters will be used. This is strongly recommended to achieve faster
#'        results.
#' @param ftol convergence tolerance on the value of the objective function
#' @param wtol convergence tolerance on the values of the parameters
#' @return a list containing possibly the following elements:
#' \item{\code{w}}{optimal portfolio vector}
#' \item{\code{theta}}{the optimal value for theta (in case that it is part of the chosen formulation}
#' \item{\code{obj_fun}}{the sequence of values from the objective function at each iteration}
#' \item{\code{elapsed_time}}{elapsed time recorded at every iteration}
#' \item{\code{convergence}}{flag to indicate whether or not the optimization converged.
#' The value `1` means it has converged, and `0` otherwise.}
#' \item{\code{risk_contribution}}{the risk contribution of every asset}
#'
#' @author Ze Vinicius and Daniel P. Palomar
#' @export
riskParityPortfolio <- function(Sigma, b = NULL, mu = NULL,
                                lmd_mu = 1e-4, lmd_var = 0,
                                budget = TRUE, shortselling = FALSE,
                                algorithm = c("newton", "cyclical"),
                                method = c("sca", "alabama", "slsqp"),
                                formulation = NULL, w0 = NULL, theta0 = NULL,
                                gamma = .9, zeta = 1e-7, tau = NULL,
                                maxiter = 50, ftol = 1e-8, wtol = 1e-6,
                                use_gradient = TRUE) {
  if (is.null(b))
    b <- rep(1/nrow(Sigma), nrow(Sigma))
  formulations <- c("rc-double-index", "rc-over-b-double-index",
                    "rc-over-var vs b", "rc-over-var",
                    "rc-over-sd vs b-times-sd", "rc vs b-times-var",
                    "rc vs theta", "rc-over-b vs theta")
  has_formulation <- !is.null(formulation)
  if (has_formulation && formulation == "diag") {
    return(riskParityPortfolioDiagSigma(Sigma, b))
  }
  has_mu <- !is.null(mu)
  has_theta <- !is.null(theta0)
  is_modern <- has_mu || has_theta || shortselling || (!budget) || has_formulation
  if (!is_modern) {
    switch(match.arg(algorithm),
           "newton" = {
             portfolio <- riskParityPortfolioNewton(Sigma, b, maxiter, ftol)
           }, "cyclical" = {
             portfolio <- riskParityPortfolioCyclical(Sigma, b, maxiter, ftol)
           },
           stop("algorithm ", algorithm, "is not included.")
    )
  } else {
    if (is.null(w0)) {
      switch(match.arg(algorithm),
             "newton" = {
               w0 <- riskParityPortfolioNewton(Sigma, b, maxiter, ftol)$w
             }, "cyclical" = {
               w0 <- riskParityPortfolioCyclical(Sigma, b, maxiter, ftol)$w
             },
             stop("algorithm ", algorithm, "is not included.")
      )
    }
    switch(match.arg(method),
           "sca" = {
              portfolio <- riskParityPortfolioSCA(Sigma = Sigma, b = b, mu = mu, lmd_mu = lmd_mu,
                                                  lmd_var = lmd_var, budget = budget,
                                                  shortselling = shortselling,
                                                  formulation = formulation, w0 = w0,
                                                  theta0 = theta0, gamma = gamma, zeta = zeta,
                                                  tau = tau, maxiter = maxiter, ftol = ftol, wtol = wtol)
           },
           "slsqp" =,
           "alabama" = {
              portfolio <- riskParityPortfolioGenSolver(Sigma = Sigma, b = b, mu = mu, lmd_mu = lmd_mu,
                                                        budget = budget, shortselling = shortselling,
                                                        formulation = formulation, method = method,
                                                        use_gradient = use_gradient, w0 = w0, theta0 = theta0,
                                                        maxiter = maxiter, ftol = ftol, wtol = wtol)

           },
           stop("method ", method, "is not included.")
    )
  }
  return(portfolio)
}
