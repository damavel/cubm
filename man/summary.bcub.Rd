% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/summary.bcub.R
\name{summary.bcub}
\alias{summary.bcub}
\title{summary.bcub}
\usage{
\method{summary}{bcub}(mod)
}
\arguments{
\item{mod}{An object of class \code{bcub}.}
}
\description{
Summarizes a cub model.
}
\examples{
# rcub.covariates is a function to generate a random sample from a cub model 
# using covariates to model pi and xi and link function qnorm
rcub.covariates <- function(n, b0, b1, g0, g1, m = 5, shift = 1) {
  x1 <- runif(n)
  x2 <- runif(n)
  pi <- pnorm(b0 + b1 * x1)
  xi <- pnorm(g0 + g1 * x2)
  y <- rcub(n = n, pi = pi, xi = xi, m = m, shift = shift)
  data.frame(y, x1, x2)
}

# Generating the data
dataset <- rcub.covariates(n=1000, b0=-1, b1=1, g0=-2, g1=1.5)
# Fitting the model
mod <- cub(pi.fo = y ~ x1, xi.fo = ~ x2, m=5, data=dataset, optimizer='nlminb')
summary(mod)

}
