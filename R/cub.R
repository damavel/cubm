#' cub
#' 
#' Function to fit a cub model. The structure can have covariates or not to model \eqn{\pi} and \eqn{\xi} parameters.
#' 
#' @param pi.fo an object of class \code{\link[stats]{formula}}, a symbolic description of the model to fit pi parameter.
#' @param xi.fo an object of class \code{\link[stats]{formula}}, a symbolic description of the model to fit xi parameter without left side.
#' @param m the maximum value of the response variable.
#' @param shift the minimum value of the response variable.
#' @param data an optional data frame.
#' @param subset an optional vector specifying a subset of observations to be used. For example, \code{subset = "sex =='male'"} means that we want to use only the male data set.
#' @param optimizer two options are available: \code{\link[stats]{nlminb}} (default), \code{\link[stats]{optim}} or \code{\link[DEoptim]{DEoptim}}.
#' @param pi.link link function to use for model pi parameter, two options are available, logit or probit, by default is probit.
#' @param xi.link link function to use for model xi parameter, two options are available, logit or probit, by default is probit.
#' @param ... Further arguments to be passed to \code{\link[DEoptim.control]{DEoptim.control}}.
#' 
#' @examples
#' 
#' # Test 1 ------------------------------------------------------------------
#' # Generating a random sample given the values of pi and xi
#' set.seed(12378)
#' y <- rcub(n=1000, pi=0.15, xi=0.60, m=5)
#' mod1 <- cub(pi.fo = y ~ 1, xi.fo = ~ 1, m=5, shift=1, optimizer='nlminb')
#' # Summary table
#' summary(mod1)
#' # To obtain the fitted parameters in the appropiate scale
#' # we need to apply the inverse link function to the fitted parameters
#' pnorm(mod1$par)
#' 
#' # Using logit link function
#' mod2 <- cub(pi.fo = y ~ 1, xi.fo = ~ 1, m=5, shift=1, optimizer='nlminb',
#'             pi.link='logit', xi.link='logit')
#' # Summary table
#' summary(mod2)
#' # To obtain the fitted parameters in the appropiate scale we need
#' # to apply the inverse link function (logit) to the fitted parameters
#' 1 / (1 + exp(-mod2$par))
#' 
#' # Using DEoptim optimizer, it is slower but it gives good results
#' mod3 <- cub(pi.fo = y ~ 1, xi.fo = ~ 1, m=5, shift=1,
#'             optimizer='DEoptim', trace=50, itermax=300)
#' # Summary table
#' summary(mod3)
#' # we need to apply the inverse link function to obtain the parameters
#' pnorm(mod3$par)
#' 
#' # Test 2 ------------------------------------------------------------------
#' # rcub.covariates is a function to generate a random sample from a cub model 
#' # using covariates to model pi and xi and link function qnorm
#' rcub.covariates <- function(n, b0, b1, g0, g1, m = 5, shift = 1) {
#'   x1 <- runif(n)
#'   x2 <- runif(n)
#'   pi <- pnorm(b0 + b1 * x1)
#'   xi <- pnorm(g0 + g1 * x2)
#'   y <- rcub(n = n, pi = pi, xi = xi, m = m, shift = shift)
#'   data.frame(y, x1, x2, xi, pi)
#' }
#' 
#' # Generating the data
#' dataset <- rcub.covariates(n=1000, b0=-1, b1=1, g0=-2, g1=1.5)
#' 
#' # Fitting the model with optim optimizer
#' fit1 <- cub(pi.fo = y ~ x1, xi.fo = ~ x2, m=5, data=dataset,
#'             optimizer='optim')
#' summary(fit1)
#' 
#' # Fitting the model with DEoptim optimizer
#' fit2 <- cub(pi.fo = y ~ x1, xi.fo = ~ x2, m=5, data=dataset,
#'             optimizer='DEoptim', trace=0, itermax=300)
#' summary(fit2)
#' 
#' # Test 3 ------------------------------------------------------------------
#' # Simulating a dataset with qualitative variables
#' n <- 10000
#' # Betas for pi
#' b0 <- -1
#' b1 <- 1
#' # Betas for xi
#' g0 <- -2
#' g1 <- 1.5
#' 
#' beta_japan <- 1 # Coefficient for japan
#' beta_usa <- -0.7 # Coefficient for usa, france is reference level
#' 
#' # m and shift value
#' m <- 5
#' shift <- 1
#' 
#' # Simulating the dataset
#' x1 <- runif(n)
#' x2 <- runif(n)
#' country <- sample(c('france', 'japan', 'usa'), size=n, replace=T)
#' aux <- model.matrix(~country)[, -1] %*% matrix(c(beta_japan,  beta_usa))
#' pi <- pnorm(b0 + b1 * x1 + aux)
#' xi <- pnorm(g0 + g1 * x2 + aux)
#' y <- rcub(n = n, pi = pi, xi = xi, m = m, shift = shift)
#' # Dataset
#' dataset <- data.frame(y, x1, x2, country)
#' 
#' # Fitting the model
#' mod <- cub(pi.fo = y ~ x1 + country,
#'            xi.fo = ~ x2 + country, m=5, data=dataset,
#'            optimizer='optim')
#' summary(mod)
#' 
#' 
#' @export
#' 
# cub function ------------------------------------------------------------
cub <- function(pi.fo, xi.fo, m, shift=1, data=NULL, subset=NULL,
                optimizer='nlminb',
                pi.link='probit', xi.link='probit', ...) {
  if(! optimizer %in% c('nlminb', 'optim', 'DEoptim')) 
    stop("That optimizer is wrong")
  if(! pi.link %in% c('probit', 'logit')) 
    stop("That optimizer is wrong")
  if(! xi.link %in% c('probit', 'logit')) 
    stop("That optimizer is wrong")
  if (!is.null(subset)) data <- subset(data, eval(parse(text=subset)))
  
  matri <- model.matrix.cub(pi.fo, xi.fo, data)
  res <- fit.cub(matri, m=m, shift, optimizer, pi.link, xi.link, ...)
  res$pi.fo <- pi.fo
  res$xi.fo <- xi.fo
  res$parameters <- c('pi', 'xi')
  res$call <- match.call(expand.dots = FALSE)
  class(res) <- "cub"
  res
}
#' @export
# model.matrix.cub --------------------------------------------------------
model.matrix.cub <- function(pi.fo, xi.fo, data=NULL) {
  stopifnot (class(pi.fo) == 'formula')
  stopifnot (class(xi.fo) == 'formula')
  response <- all.vars(pi.fo)[1]
  xi.fo <- as.formula(paste(response, paste(as.character(xi.fo),
                                            collapse='')))
  mat.pi <- model.matrix(pi.fo, data)
  mat.xi <- model.matrix(xi.fo, data)
  y <- model.frame(pi.fo, data=data)[, 1]
  list(mat.pi=mat.pi, mat.xi=mat.xi, y=y)
}

# fit.cub -----------------------------------------------------------------
fit.cub <- function(matri, m, shift, optimizer, pi.link, xi.link, ...) {
  p.pi <- ncol(matri$mat.pi)  # Number of pi parameters
  p.xi <- ncol(matri$mat.xi)  # Number of xi parameters
  X.pi <- matri$mat.pi  # Model matrix to pi
  X.xi <- matri$mat.xi  # Model matrix to xi
  y <- matri$y  # Response variable
  names.pi <- colnames(matri$mat.pi)
  names.xi <- colnames(matri$mat.xi)
  
  if (optimizer == 'nlminb') {
    nlminbcontrol <- list(...)
    fit <- nlminb(start=rep(0, p.pi+p.xi), objective=llcub,
                  y=y, M=m, X.pi=X.pi, X.xi=X.xi,
                  pi.link=pi.link, xi.link=xi.link,
                  control=nlminbcontrol)
    fit$objective <- -fit$objective
  }
  
  if (optimizer == 'optim') {
    optimcontrol <- list(...)
    fit <- optim(par=rep(0, p.pi+p.xi), fn=llcub,
                 y=y, M=m, X.pi=X.pi, X.xi=X.xi,
                 pi.link=pi.link, xi.link=xi.link,
                 control=optimcontrol)
    fit$objective <- -fit$value
  }
  
  if (optimizer == 'DEoptim') {
    require(DEoptim)
    DEcontrol <- list(...)
    fit <- DEoptim(fn=llcub,
                   lower=rep(-10, p.pi+p.xi),
                   upper=rep( 10, p.pi+p.xi),
                   control=DEcontrol,
                   y, m, X.pi, X.xi,
                   pi.link, xi.link)
    fit$par <- fit$optim$bestmem
    fit$objective <- -fit$optim$bestval
  }
  
# Unifying the results
names(fit$par) <- c(names.pi, names.xi)
# Obtaining fitted pi and xi
fit$fitted.pi <- fitted.pi(p.pi, p.xi, pi.link, X.pi, fit)
fit$fitted.xi <- fitted.xi(p.pi, p.xi, pi.link, X.pi, fit)
# Obtaining the hessian
fit$Hessian <- numDeriv::hessian(func=llcub, x=fit$par,
                                 method='Richardson',
                                 y=y, M=m,
                                 X.pi=X.pi, X.xi=X.xi)
inputs <- list(y=y, M=m, shift=1, log=TRUE, p.pi=p.pi, p.xi=p.xi,
               n=length(y), 
               X.pi=X.pi,
               X.xi=X.xi,
               pi.link=pi.link,
               xi.link=xi.link)
fit <- c(fit, inputs)
}


# llcub -------------------------------------------------------------------
# This function calculates the minus log-likelihood
llcub <- function(theta, y, M, X.pi, X.xi,
                  pi.link='probit', xi.link='probit') {
  betas.pi <- matrix(theta[1:ncol(X.pi)], ncol=1)
  #betas.xi <- matrix(theta[-(1:ncol(X.pi))], ncol=1)
  betas.xi <- matrix(theta[(ncol(X.pi)+1) : (ncol(X.pi)+ncol(X.xi))], ncol=1)
  pi <- pnorm(X.pi %*% betas.pi)
  xi <- pnorm(X.xi %*% betas.xi)
  if (pi.link == 'logit') pi <- 1 / (1 + exp(- X.pi %*% betas.pi))
  if (xi.link == 'logit') xi <- 1 / (1 + exp(- X.xi %*% betas.xi))
  ll <- sum(dcub(pi=pi, xi=xi, x=y, m=M, log=TRUE))
  -ll  # minus to use with optim/nlminb function
}

# fitted.pi and fitted.xi -------------------------------------------------
fitted.pi <- function(p.pi, p.xi, pi.link, X.pi, fit) {
  betas.pi <- matrix(fit$par[1:ncol(X.pi)], ncol=1)
  betas.xi <- matrix(fit$par[-(1:ncol(X.pi))], ncol=1)
  if  (p.pi != 1 && pi.link =='probit')
  {pi <- pnorm(X.pi %*% betas.pi)}
  else if (p.pi == 1 && pi.link == 'probit')
  {pi <- pnorm(betas.pi)}
  else if (p.pi != 1 && pi.link =='logit')
  {pi <- 1/(1 + exp(-(X.pi %*% betas.pi)))}
  else pi <- 1/(1 + exp(-beta.pi))  
  return(pi)    
}

fitted.xi <- function(p.pi, p.xi, xi.link, X.xi, fit) {
  betas.pi <- matrix(fit$par[1:ncol(X.pi)], ncol=1)
  betas.xi <- matrix(fit$par[-(1:ncol(X.pi))], ncol=1)
  if (p.xi != 1 && xi.link =='probit')
  {xi <- pnorm(X.xi %*% betas.xi)} 
  else if (p.xi == 1 && xi.link == 'probit')
  {xi <- pnorm(betas.xi)}
  else if (fit$p.xi != 1 && fit$xi.link =='logit')
  {xi <- 1/(1 + exp(-(X.pi %*% betas.xi)))}
  else xi <- 1/(1 + exp(-betas.xi))
  return(xi)    
}





