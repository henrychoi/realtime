
R <- 2      # Number of passes
L <- 256    
K <- 4      # Sample vector size
N <- L * K  # Pool size

# Constants for chi-square correction.
c1 <- sqrt(sqrt(1.0-(1.0/N)))
c2 <- sqrt(1.0 - c1^2)

# Initialize with standard normal variates.
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
      # TODO: sample once, and do bit manipulation, like the Lee paper
      kidx <- sample(1:N, K, replace=F) 
      kvals <- normvals[kidx]
      normvals[kidx] <<- transformK(kvals, j)
    }
  }
}  

oneClock <- function()
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
  
  kidx <- sample(1:N, K, replace=F) 
  kvals <- normvals[kidx]
  normvals[kidx] <<- transformK(kvals, j)
  
}

wallaceAlgorithm <- function()
{
  # Compute the initial chi-square correction factor.
  GScale <- sqrt(renormalize()/N)
  
  # Compute the new chi-square factor.
  GScale <- c1 + (c2*GScale*normvals[-1])
  
  reshuffle()
  
  return(GScale*normvals[1:N-1])
}

badData <- c()
prevData <- rep(0,N-1)

runPools <- function(n, r=2)
{
  R <<- r
  x <- do.call(rbind, lapply(1:n, function(x) {
    nv <- wallaceAlgorithm()
    st <- shapiro.test(nv)
    if (st$p.value < 0.005)
    {
      badData <<- nv
    }
    prevcor <- cor(prevData,nv)
    prevData <<- nv
    data.frame(round=x, p.value=st$p.value, r=r,prevcor=prevcor)
  }))  
}

