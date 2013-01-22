/*	This is file FastNorm2.c	*/
/*	Supersedes FastNorm.c, which SHOULD NOT BE USED.   */
/*	Revision date 25 June 1998   */
/*	Revised 25-6-1998 to obtain the ChiSquared_1024 variable used in
forming GScale from an unused entry in the previous pool, not from an entry
in the new pool. This change seems succesful in removing a correlation
between GScale and the sum-of-squares of the pool it modifies. The correlation
showed up in the variance of the ChiSq variable formed by summing the squares
of N succesive Normals. For N about 400, the variance was too small by about
0.1%. It now seems OK.
	*/
/*	It is a double-precsion floating-point version of FastNorm.c
	Use with FastNorm2.h.   */

/*	*************   Calling macro now changed to  ****************
	*************    "FastNorm"		      ****************
	*/

/*	The older version "FastNorm" which was available via ftp was found
to have a defect which could affect some applications.

	Dr Christine Rueb, (Max Planck Institut fur Infomatik,
		Im Stadtwald W 66123 Saabrucken, F.G.R.,
			(rueb@mpi-sb.mpg.de)

found that if a large number N of consecutive variates were summed to give
a variate S with nominally N(0,N) distribution, the variance of S was in some
cases too small. The effect was noticed with N=400, and was particularly strong
for N=1023 if the first several (about 128) variates from FastNorm were
discarded. Dr. Rueb traced the effect to an unexpected tendency of FastNorm
to concentrate values with an anomolous correlation into the first 128
elements of the variate pool.
	With the help of her analysis, the algorithm has been revised in a
way which appears to overcome the problem, at the cost of about a 19%
reduction in speed (which still leaves the method very fast.)
	The new algorithm was first developed using integer variates in the
pool, in the same style as the original FastNorm. However, it turned out that
the new version runs just as quickly if double-precision floating-point
variates are used, at least on machines with reasonable floating-point
performance. In fact on some machines (e.g. SG Indy) the floating point
form is noticably faster. FastNorm2 is therefore presented in floating-point
form. The change from fixed to floating point has no effect on the basic
statistical properties of the new algorithm (or in its defects if any), but
offers the advantage of higher-precision variates and a reduced rate of drift
in the pool sum-of-squares.
	The integer version is available as intFastNorm2.c, intFastNorm2.h

	IT  MUST  BE  RECOGNISED  THAT  THIS  ALGORITHM  IS  NOVEL
AND  WHILE  IT  PASSES  A  NUMBER  OF  STANDARD  TESTS  FOR  DISTRIBUTIONAL
FORM,  LACK  OF  SERIAL  CORRELATION  ETC.,  IT  MAY  STILL  HAVE  DEFECTS.

RECALL  THE  NUMBER  OF  YEARS  WHICH  IT  TOOK  FOR  THE  LIMITATIONS  OF
THE  LEHMER  GENERATOR  FOR  UNIFORM  VARIATES  TO  BECOME  APPARENT !!!

UNTIL  MORE  EXPERIENCE  IS  GAINED  WITH  THIS  TYPE  OF  GENERATOR,  IT
WOULD  BE  WISE  IN  ANY  CRITICAL  APPLICATION  TO  COMPARE  RESULTS
OBTAINED  USING  IT  WITH  RESULTS  OBTAINED  USING  A  "STANDARD"  FORM
OF  GENERATOR  OF  NORMAL  VARIATES  COUPLED  WITH  A  WELL-DOCUMENTED
GENERATOR  OF  UNIFORM  VARIATES.
	*/


/*	Revised to use "Sw" as type for 32-bit integers. Depending on
compiler, Sw should be defined as long or int in FastNorm2.h
	Also modified to include and use a function c7rand() for Uniform
pseudo-random integers. This is designed to be less dependent on details
of machine arithmetic, and to have a long period. It works OK in this
application,  and has been faily well tested in other uses.
	*/

#define InFastNormCode 1
#include "FastNorm2.h"
#include <math.h>

/*	This is a revised version of the algorithm decribed in

	ACM Transactions on Mathematical Software, Vol 22, No 1
		March 1996, pp 119-127.

/*	FAST GENERATOR OF PSEUDO-RANDOM UNIT NORMAL VARIATES

		C.S.Wallace, Monash University, 1998

To use this code, files needing to call the generator should #include the
file "FastNorm2.h" and be linked with the maths library (-lm)
	FastNorm2.h contains declaration of the initialization routine
'initnorm()', definition of a macro 'FastNorm' used to generate variates,
and three variables used in the macro.
	Read below for calling conventions.
*/


/*
	A fast generator of pseudo-random variates from the unit Normal
distribution. It keeps a pool of about 1000 variates, and generates new
ones by picking 4 from the pool, rotating the 4-vector with these as its
components, and replacing the old variates with the components of the
rotated vector.


	The program should initialize the generator by calling initnorm(seed)
with seed a Sw integer seed value. Different seed values will give
different sequences of Normals. Seed may be any 32-bit integer.
Two different values of 'seed' are guaranteed to give
starting-points in the random sequence differing by at least 2 ** 31, or
10**9, so the sequences starting from different seeds are not likely to
overlap.
	Then, wherever the program needs a new Normal variate, it should
use the macro FastNorm, e.g. in statements like:
	x = FastNorm;  (Sets x to a random Normal value)
*/

#define ELEN 10		/*  TLEN must be 2 ** ELEN	*/
#define TLEN (1 << ELEN)
#define LMASK (TLEN - 1)
Sw gaussfaze;
double *gausssave;
double GScale, fastnorm2();
/*	GScale,fastnorm2,gaussfaze and gausssave must be visible to callers   */
static double ivec [TLEN];
static Sw nslew, start, mask, stride, dummy;
static double chic1, chic2, actualRSD;
static Sw c7s [2];	/*  seed values for c7rand  */


/*	--------------------------------------------------------     */
/*	-----------------   c7rand, irandm, srandm  ---------------
c	A random number generator called as a function by
c	c7rand (iseed)	or	irandm (iseed)  or srandm (iseed)

	*/


/*
c	The parameter should be a pointer to a 2-element Sw vector.
c	The first call gives a double uniform in 0 .. 1.
c	The second gives an Sw integer uniform in 0 .. 2**31-1
c	The third gives an Sw integer with 32 bits, so unif in
c	-2**31 .. 2**31-1 if used in 32-bit signed arithmetic.
c	All update iseed[] in exactly the same way.
c	iseed[] must be a 2-element Sw vector.
c	The initial value of iseed[1] may be any 32-bit integer.
c	The initial value of iseed[0] may be any 32-bit integer except -1.
c
c	The period of the random sequence is 2**32 * (2**32-1)

c	This is an implementation in C of the algorithm described in
c	Technical Report "A Long-Period Pseudo-Random Generator"
c	TR89/123, Computer Science, Monash University,
c	   Clayton, Vic 3168 AUSTRALIA
c			by
c
c		C.S.Wallace     csw@cs.monash.edu.au

c	The table mt[0:127] is defined by mt[i] = 69069 ** (128-i)
	*/

#define MASK ((Sw) 0x12DD4922)
/*	or in decimal, 316492066	*/
#define SCALE ((double) 1.0 / (1024.0 * 1024.0 * 1024.0 * 2.0))
/*	i.e. 2 to power -31	*/

static Sw mt [128] =   {
      902906369,
     2030498053,
     -473499623,
     1640834941,
      723406961,
     1993558325,
     -257162999,
    -1627724755,
      913952737,
      278845029,
     1327502073,
    -1261253155,
      981676113,
    -1785280363,
     1700077033,
      366908557,
    -1514479167,
     -682799163,
      141955545,
     -830150595,
      317871153,
     1542036469,
     -946413879,
    -1950779155,
      985397153,
      626515237,
      530871481,
      783087261,
    -1512358895,
     1031357269,
    -2007710807,
    -1652747955,
    -1867214463,
      928251525,
     1243003801,
    -2132510467,
     1874683889,
     -717013323,
      218254473,
    -1628774995,
    -2064896159,
       69678053,
      281568889,
    -2104168611,
     -165128239,
     1536495125,
      -39650967,
      546594317,
     -725987007,
     1392966981,
     1044706649,
      687331773,
    -2051306575,
     1544302965,
     -758494647,
    -1243934099,
      -75073759,
      293132965,
    -1935153095,
      118929437,
      807830417,
    -1416222507,
    -1550074071,
      -84903219,
     1355292929,
     -380482555,
    -1818444007,
     -204797315,
      170442609,
    -1636797387,
      868931593,
     -623503571,
     1711722209,
      381210981,
     -161547783,
     -272740131,
    -1450066095,
     2116588437,
     1100682473,
      358442893,
    -1529216831,
     2116152005,
     -776333095,
     1265240893,
     -482278607,
     1067190005,
      333444553,
       86502381,
      753481377,
       39000101,
     1779014585,
      219658653,
     -920253679,
     2029538901,
     1207761577,
    -1515772851,
     -236195711,
      442620293,
      423166617,
    -1763648515,
     -398436623,
    -1749358155,
     -538598519,
     -652439379,
      430550625,
    -1481396507,
     2093206905,
    -1934691747,
     -962631983,
     1454463253,
    -1877118871,
     -291917555,
    -1711673279,
      201201733,
     -474645415,
      -96764739,
    -1587365199,
     1945705589,
     1303896393,
     1744831853,
      381957665,
     2135332261,
      -55996615,
    -1190135011,
     1790562961,
    -1493191723,
      475559465,
	  69069
		};

double c7rand (is)
	Sw is [2];
{
	Sw it, leh;

	it = is [0];
	leh = is [1];
/*	Do a 7-place right cyclic shift of it  */
	it = ((it >> 7) & 0x01FFFFFF) + ((it & 0x7F) << 25);
	if (!(it & 0x80000000)) it = it ^ MASK;
	leh = (leh * mt[it & 127] + it) & 0xFFFFFFFF;
	is [0] = it;    is [1] = leh;
	if (leh & 0x80000000) leh = leh ^ 0xFFFFFFFF;
	return (SCALE * ((Sw) (leh | 1)));
}



Sw irandm (is)
	Sw is [2];
{
	Sw it, leh;

	it = is [0];
	leh = is [1];
/*	Do a 7-place right cyclic shift of it  */
	it = ((it >> 7) & 0x01FFFFFF) + ((it & 0x7F) << 25);
	if (!(it & 0x80000000)) it = it ^ MASK;
	leh = (leh * mt[it & 127] + it) & 0xFFFFFFFF;
	is [0] = it;    is [1] = leh;
	if (leh & 0x80000000) leh = leh ^ 0xFFFFFFFF;
	return (leh);
}


Sw srandm (is)
	Sw is [2];
{
	Sw it, leh;

	it = is [0];
	leh = is [1];
/*	Do a 7-place right cyclic shift of it  */
	it = ((it >> 7) & 0x01FFFFFF) + ((it & 0x7F) << 25);
	if (!(it & 0x80000000)) it = it ^ MASK;
	leh = (leh * mt[it & 127] + it) & 0xFFFFFFFF;
	is [0] = it;    is [1] = leh;
	return (leh);
}
/*	---------------------------------------------    */

/*	Initinorm is called with an integer seed to initialize the Normal
	generator. 'seed' may be any 32-bit integer.
	*/

/*	The following define causes verification that the algorithm is
performing correctly.  If any alteration is made to the algorithm, this
check will probably fail. Disable it by removing the definition of INITchk,
and after checking the altered algorithm, re-install the check, replacing
the constants dchk1, dchk2 and rchk against which checks are made in the 
section of code following "ifdef INITchk".  The constants follow in initnorm.
	*/
#define INITchk 1

void initnorm (seed)
	Sw seed;
{
	double dchk1 = -1.01604271;
	double dchk2 = 1.23903847;
	double rchk = -1.00886113;

	Sw i, j;
	double fake;
/*	At one stage, we need to generate a random variable Z such that
	(TLEN * Z*Z) has a Chi-squared-TLEN density. Now, a var with
	an approximate Chi-sq-K distn can be got as
		0.5 * (C + A*n)**2  where n has unit Normal distn,
	A = (1 + 1 / (8K)),  C*C = 2K - A*A    (For large K)
		So we form Z as (sqrt (1 / 2TLEN)) * (C + A*n)
	or:
		Z = (sqrt (1/2TLEN)) * A * (B + n)
	where:
		B = C / A.
	We set chic1 = A * sqrt (0.5 / TLEN),  chic2 = B
	*/
	fake = 1.0 + 0.125 / TLEN;   /* This is A  */
	chic2 = sqrt (2.0 * TLEN  -  fake*fake) /  fake;
	chic1 = fake * sqrt (0.5 / TLEN);

/*	Now we do a section to verify that the main part of the code
	is working correctly. We set up a known pattern of values in the
vector, initialize the Uniform generator to a known state, then transform
the vector several times and check that we get the correct entries in a
couple of positions in the vector. We can't check the regeneration code
which uses Box-Muller to create Normal values, as this may depend on detailed
floating-point roundoff.   */

/*	Set nslew to 3 so no regeneration or rescaling will be done. */
	nslew = 3;  actualRSD = 1.0;
	start = mask = stride = 1;
#ifdef INITchk
	c7s[0] = c7s[1] = 444333222;
/*	The above initialized c7rand(), the Uniform generator.
Now fill vector with random-signed equal-size values    */
	for (i = 0; i < TLEN; i++)	{
		ivec [i] = (irandm (c7s) & 1) ? 1.0 : -1.0;
		}
/*	Now call fastnorm2() to transform ivec several times  */
	for (i = 0; i < 20; i++) fake = fastnorm2 ();
/*	Check a couple of entries at 0 and 17  */
	if ((fabs (ivec[0]-dchk1) > 0.0000001) ||
		(fabs (ivec[17]-dchk2) > 0.0000001))	{
		printf (
"FastNorm check gave %14.8lf,%14.8lf instead of %14.8lf,%14.8lf\n",
			ivec [0], ivec [17], dchk1, dchk2);
		exit (3);
		}
/*	Also check returned Normal in 'fake', allowing for a bit of
roundoff error	*/
	if (fabs (fake - rchk) > 0.0000001)   {
		printf (
"FastNorm gave variate %14.8lf instead of %14.8lf\n",
			fake, rchk);
		exit (3);
		}
#endif

/*	Checks are OK, so really initialize using 'seed'.   */
	c7s[0] = 222229;  c7s[1] = seed;
	gaussfaze = 1;
	nslew = 0;   actualRSD = 0.0;
	start = mask = stride = 5;

	return;
}

/*	-----------------------------------------------------   */


/*	Some definitions of the method of stepping access to the elements
of the ivec pool vector.
	*/

#define CurrENT  ivec[ix^mk]
#define StepENT  ix=(ix+st)&LMASK

double fastnorm2 ()
{
	Sw i, j;
	double p, q, r, s, t;
	Sw ix, mk, st;
	double ts, tr, tx, ty, tz;

/*	See if time to make a new set of 'original' deviates  */
/*	or at least to correct for a drift in sum-of-squares	*/
	if (! (nslew & 0x7FF)) goto renormalize;

startpass:
/*	Choose a value for GScale which will make the sum-of-squares have
	the variance of Chi-Sq (TLEN), i.e., 2*TLEN.  Choose a value from
	Chi-Sq (TLEN) using the method descibed in initnorm.
	The Normal variate is obtained from gausssave[TLEN-1], which is
	not used by the caller.
	*/
	ts = chic1 * (chic2 + GScale * ivec [TLEN-1]);
/*	TLEN * ts * ts  has ChiSq (TLEN) distribution	*/
	GScale = ts * actualRSD;

/*	Count passes	*/
	nslew ++;
	gausssave = ivec;
/*	Set loop count to TLEN / 8  - 1   */
	i = TLEN / 8 - 1;
/*	Choose random start-point, stride, EOR mask.
	Need ELEN-1 bits for stride, ELEN for mask.  Discard rest from 31  */
rerand1:
        j = irandm (c7s);
	j = j >> (32 - ELEN - ELEN);
	mk = j & LMASK;
	if (mk == mask) goto rerand1;
	j = j >> (ELEN-1);	/* Should leave ELEN bits, will force last */
	st = (j & LMASK) | 1;	/* An odd stride */
	if (st == stride) goto rerand1;
	mask = mk;   stride = st;
rerand2:
	j = irandm (c7s);
/*	Need ELEN bits for start. Discard rest from 31  */
	ix = (j >> (31 - ELEN)) & LMASK;
	if (ix == start) goto rerand2;
	start = ix;
/*	Reset index into Saved values	*/
	gaussfaze = TLEN - 1;	/* We will steal the last one	*/

/*	Preload the first 4 entries of vec   */
	p = CurrENT;  StepENT;
	q = CurrENT;  StepENT;
	r = CurrENT;  StepENT;
	s = CurrENT;  StepENT;

mpass1:
	t = (p + q + r + s) * 0.5;
	p = p-t;  q = t-q;  r = t-r;  t = t-s;
/*	Have new vals in p,q,r,t. Swap with next 4 numbers  */
	s = CurrENT;   CurrENT = p;  StepENT;
	p = CurrENT;   CurrENT = q;  StepENT;
	q = CurrENT;   CurrENT = r;  StepENT;
	r = CurrENT;   CurrENT = t;  StepENT;
/*	Now have (again) 4 new numbers in p,q,r,s, so ready to repeat.  */
	i--;  if (i) goto mpass1;

/*	Set loop count to TLEN / 8  */
	i = TLEN / 8;
mpass2:
	t = (p + q + r + s) * 0.5;
	p = t-p;  q = q-t;  r = r-t;  t = s-t;
/*	Have new vals in p,q,r,t. Swap with next 4 numbers  */
	s = CurrENT;   CurrENT = p;  StepENT;
	p = CurrENT;   CurrENT = q;  StepENT;
	q = CurrENT;   CurrENT = r;  StepENT;
	r = CurrENT;   CurrENT = t;  StepENT;
/*	Now have (again) 4 new numbers in p,q,r,s, so ready to repeat.  */
	i--;  if (i) goto mpass2;

/*	We are left with 4 untransformed numbers in p,q,r,s. Transform
	and store in preloaded entries of vec.   */
/*	Note, ix has been stepped TLEN times, so should be back at start */
	t = (p + q + r + s) * 0.5;
	CurrENT = p-t;  StepENT;
	CurrENT = t-q;  StepENT;
	CurrENT = t-s;  StepENT;
	CurrENT = t-r;

	return (GScale * ivec[0]);

renormalize:
	if ((fabs (actualRSD - 1.0) < 0.0000001)
		&& (nslew & 0x7FFF))    /*  ensures refresh every 32K) */
		goto recalcsumsq;
/*	Here, replace the whole pool with conventional Normal variates  */
	ts = 0.0;
	i = 0;
nextpair:
	tx = 2.0 * c7rand(c7s) - 1.0;  /* Uniform in -1..1 */
	ty = 2.0 * c7rand(c7s) - 1.0;  /* Uniform in -1..1 */
	tr = tx * tx + ty * ty;
	if ((tr > 1.0) || (tr < 0.25)) goto nextpair;
	tz = -2.0 * log (c7rand(c7s));	/* Sum of squares */
	ts += tz;
	tz = sqrt ( tz / tr );
	ivec [i++] = tx * tz;   ivec [i++] = ty * tz;
	if (i < TLEN) goto nextpair;
/*	Horrid, but good enough	*/
/*	Calc correction factor to make sum of squares = TLEN	*/
	ts = TLEN / ts;  /* Should be close to 1.0  */
	tr = sqrt (ts);
/*	Set GScale to restore the Chisq_1024 distribution    */
	GScale = 1.0 / tr;   /* Will just reverse the scaling to sumsq = 1024*/
	for (i = 0; i < TLEN; i++)	{
		ivec [i] *= tr;
		}

recalcsumsq:
	/*	Calculate actual sum of squares for correction   */
	ts = 0.0;
	for (i = 0; i < TLEN; i++)	{	
		tx = ivec[i];
		ts += (tx * tx);
		}
/*	Now ts should be TLEN or thereabouts   */
	ts = sqrt (ts / (TLEN));
	actualRSD = 1.0 / ts;   /* Reciprocal of actual Standard Devtn */
	goto startpass;

}


/*	--------------------------------------------------------------  */
