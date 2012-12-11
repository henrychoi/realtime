/*
This main asks for the Poisson parameter lambda, then generates 10^8
random Poisson-lambda variates using the compacted 5-table method.
It then does a goodness-of-fit test on the output.
It then asks for the binomial parameters n,p, generates 10^8
binomial(n,p) variates with the compacted 5-table method and tests
the output.   Generation speed is 10-15 nanoseconds for each variate,
some 70-100 million per second.
Output is displayed on the screen and also sent to the file tests.out.
*/



#include <stdio.h>
#include <math.h>
#include <stdlib.h>

# define dg(m,k) ((m>>(30-6*k))&63)  /* gets kth digit of m (base 64) */

static int *P;   /* Probabilities as an array of 30-bit integers*/
static int size,t1,t2,t3,t4,offset,last;  /* size of P[], limits for table lookups */
static unsigned long jxr=182736531; /* Xorshift RNG */
static short int *AA,*BB,*CC,*DD,*EE;      /* Tables for condensed table-lookup */
static FILE *fp;

void get5tbls() /* Creates the 5 tables after array P[size] has been created */
{ int i,j,k,m,na=0,nb=0,nc=0,nd=0,ne=0;
    /* get table sizes, malloc */
for(i=0;i<size;i++){m=P[i];na+=dg(m,1);nb+=dg(m,2);nc+=dg(m,3);nd+=dg(m,4);ne+=dg(m,5);}
AA=malloc(na*sizeof(int));BB=malloc(nb*sizeof(int));
CC=malloc(nc*sizeof(int));DD=malloc(nd*sizeof(int));EE=malloc(ne*sizeof(int));
printf(" Table sizes:%d,%d,%d,%d,%d,total=%d\n",na,nb,nc,nd,ne,na+nb+nc+nd+ne);
fprintf(fp," Table sizes:%d,%d,%d,%d,%d,total=%d\n",na,nb,nc,nd,ne,na+nb+nc+nd+ne);
t1=na<<24; t2=t1+(nb<<18); t3=t2+(nc<<12); t4=t3+(nd<<6);
na=nb=nc=nd=ne=0;
   /* Fill tables AA,BB,CC,DD,EE */
for(i=0;i<size;i++){m=P[i]; k=i+offset;
         for(j=0;j<dg(m,1);j++) AA[na+j]=k; na+=dg(m,1);
         for(j=0;j<dg(m,2);j++) BB[nb+j]=k; nb+=dg(m,2);
         for(j=0;j<dg(m,3);j++) CC[nc+j]=k; nc+=dg(m,3);
         for(j=0;j<dg(m,4);j++) DD[nd+j]=k; nd+=dg(m,4);
         for(j=0;j<dg(m,5);j++) EE[ne+j]=k; ne+=dg(m,5);
                   }
}// end get5tbls

void PoissP(double lam)  /* Creates Poisson Probabilites */
{int i,j=-1,nlam;        /* P's are 30-bit integers, assumed denominator 2^30 */
double p=1,c,t=1.;
    /* generate  P's from 0 if lam<21.4 */
if(lam<21.4){p=t=exp(-lam); for(i=1;t*2147483648.>1;i++) t*=(lam/i);
          size=i-1; last=i-2;
          /* Given size, malloc and fill P array, (30-bit integers) */
          P=malloc(size*sizeof(int)); P[0]=exp(-lam)*(1<<30)+.5;
          for(i=1;i<size;i++) {p*=(lam/i); P[i]=p*(1<<30)+.5; }
            }
    /* If lam>=21.4, generate from largest P up,then largest down */
if(lam>=21.4)
{nlam=lam;      /*first find size */
c=lam*exp(-lam/nlam);
for(i=1;i<=nlam;i++) t*=(c/i);
p=t;
for(i=nlam+1;t*2147483648.>1;i++) t*=(lam/i);
last=i-2;
t=p; j=-1;
for(i=nlam-1;i>=0;i--){t*=((i+1)/lam); if(t*2147483648.<1){j=i;break;} }
offset=j+1;  size=last-offset+1;
   /* malloc and fill P array as 30-bit integers */
P=malloc(size*sizeof(int));
t=p; P[nlam-offset]=p*(1<<30)+0.5;
for(i=nlam+1;i<=last;i++){t*=(lam/i); P[i-offset]=t*(64<<24)+.5;}
t=p;
for(i=nlam-1;i>=offset;i--){t*=((i+1)/lam);P[i-offset]=t*(1<<30)+0.5;}
} // end lam>=21.4
} //end PoissP

void BinomP(int n, double p)  /*Creates Binomial Probabilities */
         /* Note: if n large and p near 1, generate j=Binom(n,1-p), return n-j*/
{double h,t,p0;
 int i,kb=0,ke,k=0,s;
/* first find size of P array */
p0=t=exp(n*log(1.-p));
h=p/(1.-p);
ke=n;
if(t*2147483648.>1) {k=1;kb=0;}
for(i=1;i<=n;i++)
  { t*=(n+1-i)*h/i;
  if(k==0 && t*2147483648.>1) {k=1;kb=i;}
  if(k==1 && t*2147483648.<1) {k=2;ke=i-1;}
  }
  size=ke-kb+1; offset=kb;
 /* Then malloc and assign P values as 30-bit integers */
P=malloc(size*sizeof(int));
t=p0; for(i=1;i<=kb;i++) t*=(n+1-i)*h/i;
        s=t*1073741824.+.5; P[0]=s;
for(i=kb+1;i<=ke;i++) {t*=(n+1-i)*h/i;
                       P[i-kb]=t*1073741824.+.5;
                       s+=P[i-kb];}
i=n*p-offset; P[i]+=(s-1073741824);
} //end BinomP



/* Discrete random variable generating function */

int Dran() /* Uses 5 compact tables */
{unsigned long j;
 jxr^=jxr<<13; jxr^=jxr>>17; jxr^=jxr<<5; j=(jxr>>2);
if(j<t1) return AA[j>>24];
if(j<t2) return BB[(j-t1)>>18];
if(j<t3) return CC[(j-t2)>>12];
if(j<t4) return DD[(j-t3)>>6];
return EE[j-t4];
}


double Phi(double x)
 {long double s=x,t=0,b=x,q=x*x,i=1;
    while(s!=t) s=(t=s)+(b*=q/(i+=2));
    return  .5+s*exp(-.5*q-.91893853320467274178L);
 }

double chisq(double z,int n)
{double s=0.,t=1.,q,h;
 int i;
 if(z<=0.) return (0.);
 if(n>3000) return Phi((exp(log(z/n)/3.)-1.+2./(9*n))/sqrt(2./(9*n)));
 h=.5*z;
 if(n&1){q=sqrt(z); t=2*exp(-.5*z-.918938533204673)/q;
    for(i=1;i<=(n-2);i+=2){ t=t*z/i; s+=t;}
    return(2*Phi(q)-1-s);
        }
 for(i=1;i<n/2;i++) { t=t*h/i; s+=t;}
 return (1.-(1+s)*exp(-h));
}


void Dtest(n)
/* requires static 'size', static int array P[size] */
/* generates n Dran()'s, tests output */
{ double x=0,y,s=0,*E;
  int kb=0,ke=1000,i,j=0,*M;
 E=malloc(size*sizeof(double));
 M=malloc(size*sizeof(int));
 for(i=0;i<size;i++) {E[i]=(n+0.)*P[i]/1073741824.;M[i]=0;}
 s=0; for(i=0;i<size;i++) {s+=E[i]; if(s>10){kb=i;E[kb]=s;break;} }
 s=0; for(i=size-1;i>0;i--) {s+=E[i]; if(s>10){ke=i;E[ke]=s;break;} }
 j=0; for(i=0;i<=kb;i++) j+=M[i]; M[kb]=j;
 j=0; for(i=ke;i<size;i++) j+=M[i]; M[ke]=j;
 for(i=0;i<size;i++) M[i]=0; s=0; x=0;
 for(i=0;i<n;i++) {j=Dran(); if(j<kb+offset) j=kb+offset;
                           if(j>ke+offset) j=ke+offset;
                        M[j-offset]++;}
printf("\n   D     Observed     Expected    (O-E)^2/E   sum\n");
fprintf(fp,"\n   D     Observed     Expected    (O-E)^2/E   sum\n");
 for(i=kb;i<=ke;i++){ y=M[i]-E[i]; y=y*y/E[i]; s+=y;

 printf("%4d %10d  %12.2f   %7.2f   %7.2f\n",i+offset,M[i],E[i],y,s);
 fprintf(fp,"%4d %10d   %12.2f   %7.2f   %7.2f\n",i+offset,M[i],E[i],y,s);
                  }
 printf("    chisquare for %d d.f.=%7.2f, p=%7.5f\n",ke-kb,s,chisq(s,ke-kb));
 fprintf(fp,"     chisquare for %d d.f.=%7.2f, p=%7.5f\n",ke-kb,s,chisq(s,ke-kb));
}

int main(){
int j=0,n,nsmpls=100000000;
double lam,p;
fp=fopen("tests.out","w");
printf("  Enter lambda:\n");
scanf("%lf",&lam);
PoissP(lam); get5tbls();
//printf("start"); for(n=0;n<1000000000;n++) j+=Dran(); printf("END\n"); //15 nanos
Dtest(nsmpls);
fprintf(fp," Above results for sample of %d from Poisson, lambda=%3.2f\n\n",nsmpls,lam);
free(P);
printf("\n Enter n and p for Binomial:\n");
scanf("%d %lf",&n,&p);
BinomP(n,p);get5tbls();
Dtest(nsmpls);
fprintf(fp," Above result for sample of %d from Binomial(%d,%3.3f)\n\n",nsmpls,n,p);
free(P);
printf(" Test results sent to file tests.out\n");
return 0;
}
