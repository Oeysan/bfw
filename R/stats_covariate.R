#' @title Covariate
#' @description Covariate estimations (including correlation and Cronbach's alpha)
#' @param y criterion variable(s), Default: NULL
#' @param y.names optional names for criterion variable(s), Default: NULL
#' @param DF data to analyze
#' @param params define parameters to observe, Default: NULL
#' @param initial.list initial values for analysis, Default: list()
#' @param ... further arguments passed to or from other methods
#' @return covariate, correlation and (optional) Cronbach's alpha
#' @examples
#' # Create normal distributed data with mean = 0 and standard deviation = 1
#' ## r = 0.5
#' data <- MASS::mvrnorm(n=100,
#'                       mu=c(0, 0),
#'                       Sigma=matrix(c(1, 0.5, 0.5, 1), 2),
#'                       empirical=TRUE)
#' # Add names
#' colnames(data) <- c("X","Y")
#' # Create noise with mean = 10 / -10 and sd = 1
#' ## r = -1.0
#' noise <- MASS::mvrnorm(n=2,
#'                        mu=c(10, -10),
#'                        Sigma=matrix(c(1, -1, -1, 1), 2),
#'                        empirical=TRUE)
#' # Combine noise and data
#' biased.data <- rbind(data,noise)
#'
#'
#' # Run analysis on normal distributed data
#' \donttest{
#' mcmc <- bfw(project.data = data,
#'             y = "X,Y",
#'             saved.steps = 50000,
#'             jags.model = "covariate",
#'             jags.seed = 100,
#'             silent = TRUE)
#' }
#' # Run robust analysis on normal distributed data
#' \donttest{
#' mcmc.robust <- bfw(project.data = data,
#'                    y = "X,Y",
#'                    saved.steps = 50000,
#'                    jags.model = "covariate",
#'                    run.robust = TRUE,
#'                    jags.seed = 101,
#'                    silent = TRUE)
#' }
#' # Run analysis on data with outliers
#' \donttest{
#' biased.mcmc <- bfw(project.data = biased.data,
#'                    y = "X,Y",
#'                    saved.steps = 50000,
#'                    jags.model = "covariate",
#'                    jags.seed = 102,
#'                    silent = TRUE)
#' }
#' # Run robust analysis on data with outliers
#' \donttest{
#' biased.mcmc.robust <- bfw(project.data = biased.data,
#'                           y = "X,Y",
#'                           saved.steps = 50000,
#'                           jags.model = "covariate",
#'                           run.robust = TRUE,
#'                           jags.seed = 103,
#'                           silent = TRUE)
#' }
#' # Print frequentist results
#' stats::cor(data)[2]
#' # [1] 0.5
#' stats::cor(noise)[2]
#' # [1] -1
#' stats::cor(biased.data)[2]
#' # [1] -0.498
#'
#' # Print Bayesian results
#' \donttest{ mcmc$summary.MCMC }
#' #                   Mean Median  Mode   ESS HDIlo HDIhi   n
#' # cor[1,1]: X vs. X 1.000  1.000 0.999     0 1.000 1.000 100
#' # cor[2,1]: Y vs. X 0.488  0.491 0.496 19411 0.337 0.633 100
#' # cor[1,2]: X vs. Y 0.488  0.491 0.496 19411 0.337 0.633 100
#' # cor[2,2]: Y vs. Y 1.000  1.000 0.999     0 1.000 1.000 100
#' \donttest{ mcmc.robust$summary.MCMC }
#' #                   Mean Median  Mode   ESS HDIlo HDIhi   n
#' # cor[1,1]: X vs. X 1.00  1.000 0.999     0 1.000 1.000 100
#' # cor[2,1]: Y vs. X 0.47  0.474 0.491 18626 0.311 0.626 100
#' # cor[1,2]: X vs. Y 0.47  0.474 0.491 18626 0.311 0.626 100
#' # cor[2,2]: Y vs. Y 1.00  1.000 0.999     0 1.000 1.000 100
#' \donttest{ biased.mcmc$summary.MCMC }
#' #                    Mean Median   Mode   ESS  HDIlo  HDIhi   n
#' # cor[1,1]: X vs. X  1.000  1.000  0.999     0  1.000  1.000 102
#' # cor[2,1]: Y vs. X -0.486 -0.489 -0.505 19340 -0.627 -0.335 102
#' # cor[1,2]: X vs. Y -0.486 -0.489 -0.505 19340 -0.627 -0.335 102
#' # cor[2,2]: Y vs. Y  1.000  1.000  0.999     0  1.000  1.000 102
#' \donttest{ biased.mcmc.robust$summary.MCMC }
#' #                   Mean Median  Mode   ESS HDIlo HDIhi   n
#' # cor[1,1]: X vs. X 1.000  1.000 0.999     0 1.000 1.000 102
#' # cor[2,1]: Y vs. X 0.338  0.343 0.356 23450 0.125 0.538 102
#' # cor[1,2]: X vs. Y 0.338  0.343 0.356 23450 0.125 0.538 102
#' # cor[2,2]: Y vs. Y 1.000  1.000 0.999     0 1.000 1.000 102
#' @seealso
#'  \code{\link[stats]{complete.cases}}
#' @rdname StatsCovariate
#' @export
#' @importFrom stats complete.cases
StatsCovariate <- function(y,
                      y.names,
                      DF,
                      params,
                      initial.list,
                      ...
) {

  # Select variables to analyze
  y <- TrimSplit(y)

  # If empty create job name
  if (is.null(job.title)) job.title <- CapWords(paste(y,collapse="-"))

  # If empty create name list
  job.names <- if (!is.null(y.names)) TrimSplit(y.names) else CapWords(colnames(DF[,y]))

  # If x.names and x are of unequal length
  if ( length(job.names) != length(y) ) {
    warning("y.names and y have unequal length. Using variable names.")
    job.names <- CapWords(colnames(DF[,y]))
  }

  # Create matrix
  y <- DF[,y]

  # Number of items
  q <- length(y[1, ])

  # Number of dimension permutations 8! / (8 - 2)!= 56
  m1 <- t(combn(1:q, 2))

  # Permutations as a continuous matrix
  m2 <- matrix(1:length(m1), length(m1) / 2, 2, byrow = TRUE)

  # Create matrix of pairwise combinations of variables
  y <- lapply(1:nrow(m1), function (i) {
    m <- cbind( y[ , m1[i,1] ] , y[ , m1[i,2] ] )
    m[stats::complete.cases(m) , ]
  } )

  # Number of observations in each y
  n <- unlist(lapply(y,nrow))

  # Max length of y
  n.max <- max(n)

  # Final data matrix
  y <- do.call(cbind,lapply(y, function(x) {
    rbind(x, matrix(NA, nrow=n.max-nrow(x), ncol=2) )
  }))

  # Create crosstable for y parameters
  n.data <- data.frame(t(combn(job.names, 2)),n)

  # Paramter(s) of interest
  params <- if(length(params)) TrimSplit(params) else c("cor")

  # Create data for Jags
  data.list <- list(
    n = n,
    q = q,
    y = y,
    m1 = m1,
    m2 = m2
  )

  # Create name list
  name.list <- list(
    job.names = job.names
  )

  # Return data list
  return (list(
    data.list = data.list,
    name.list = name.list,
    params = params,
    n.data = n.data
  ))

}