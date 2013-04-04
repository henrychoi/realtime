
R <- 2
L <- 256
K <- 4
N <- L * K

# Constants for chi-square correction.
c1 <- sqrt(sqrt(1.0-(1.0/N)))
c2 <- sqrt(1.0 - c1^2)

normvals <- rnorm(N)

renormalize <- function() 
{
  # Normalizes standard normals so that
  # sum-of-squares is equal to N.
  ts <- sum(normvals^2)
  vf <- sqrt(N/ts)
  normvals <<- normvals * vf
  return(ts)
}

reshuffle <- function()
{
  # Transformation function.
  transformK <- function(kvals, ntransform) {
    t <- sum(kvals) / 2
    
    if (ntransform %% 2 == 0) {   # Even
      tk <- c(t - kvals[1],
              t - kvals[2],
              kvals[3] - t,
              kvals[4] - t)
    } else {                      # Odd
      tk <- c(kvals[1] - t,
              kvals[2] - t,
              t - kvals[3],
              t - kvals[4])
    }
      
    return(tk)
  }
  
  # Run the passes.
  for (i in 1:R) {        # Number of passes
    for (j in 1:L) {      # Number of transformations
      # Permute the address first.
      # Grab K random values out of pool to transform.
      kidx <- sample(1:N, K, replace=F) 
      kvals <- normvals[kidx]
      normvals[kidx] <<- transformK(kvals, j)
    }
  }
}  
  
wallaceAlgorithm <- function()
{
  GScale <- sqrt(renormalize()/N)
  GScale <- c1 + (c2*GScale*normvals[-1])
  reshuffle()
  return(GScale*normvals[1:N-1])
}