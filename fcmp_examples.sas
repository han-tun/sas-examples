/* PROC FCMP allows you to use datstep-like logic to generate custom functions and call routines.
   FCMP can be very useful for simplifying code and applying custom functions to procs that support it.
   In addition, %sysfunc() works with PROC FCMP functions as well.
   SAS functions, conditional logic, and even other FCMP functions are all supported within PROC FCMP.

   Functions are stored within datasets as packages. For example, you may have a dataset with
   a family of functions devoted to time. You can load these packages as needed with the OPTIONS CMPLIB=(3-LEVEL LIBNAME) statement.
   To store custom functions, you must output it as a 3-level libname statement.

   The 3-level libname statement is a bit unique to PROC FCMP. The name "outlib" is a little deceptive, 
   as it does not behave like your normal libname statement. In a 3-level libname statement
   in PROC FCMP:

	x.y.z

	x: Output library
	y: Output dataset name containing functions
	z: Identifying family of functions (AKA package) to store within the dataset

	In practice, you might use only one dataset with multiple packages in it, or even one
    dataset all with the same package name for convenience.
	This can make it easier to transport your custom functions to other environments.
*/
	
/********* Example 1: Numeric Functions *********/

/* In the example below, let's say you are working with a company whose Fiscal Year ends in
   July rather than in January. For example, in July of 2020, they will report the year as 2021. 
   The below series of functions can do this:

   Fiscal_Year = year(intnx('year.7', date, 1, 'B'));

   We want to take this set of logic and turn it into one function named fy().
*/
proc fcmp outlib=work.funcs.time;
	function fy(date);
		fy = year(intnx('year.7', date, 1, 'B'));
		return(fy);
	endsub;
run;

/* The dataset "work.funcs" has been created. Within "work.funcs," the package "time" is also created.
   You can load this package with the OPTIONS CMPLIB=(3-LEVEL LIBNAME) statement.
*/
options cmplib=(work.funcs.time);

data fy;
	format date date9.;

	date = '01JUL2020'd;
	fiscal_year = fy(date);
run;


/********* Example 2: String Functions *********/
/* PROC FCMP also supports string functions. 
   The below function will take a space-separated string,
   convert quote each item, then add a comma between them.
   For example:

   a b c
-> "a","b","c"

*/
proc fcmp outlib=work.funcs.string;
	function cquote(strin$) $ 200;	/* Returns a char function of max length */
		length strout 	  $32767
			   token
			   next_token $1
		;

		strclean = compbl(strin);
		strout 	 = '"';

		do i = 1 to length(strclean);
			token 	   = substr(strclean, i, 1);
			next_token = substr(strclean, i+1, 1);

			if(i < length(strclean) ) then do;
				if(token = ' ') then strout = catt(strout, '","');
					else strout = catt(strout, token);
			end;
				else strout = catt(strout, token, '"');
		end;

		return(strout);
	endsub;
run;

options cmplib=(work.funcs.string);

/* This function can make macro variable lists easier to work with. 
   Now users can just space-separate a list and cquote can comma/quote it
   for IN() statements.
*/
%let mylist = cars class air;

/* Note: there's a bug in 9.4M5 that will produce an error. There is a hotfix for this:
   https://support.sas.com/kb/62/306.html
   A workaround is to use call symputx instead.

*/
/*%let mylistcq = %sysfunc(cquote(&mylist.));*/

data _null_;
	call symputx('mylistcq', upcase(cquote("&mylist.")) );
run;

proc sql noprint;
	create table vars as
		select *
		from dictionary.columns
		where memname IN(&mylistcq.)
	;
quit;

/********* Example 3: Subroutines *********/

/* PROC FCMP also supports creating subroutines (call functions) 
   Taken from: https://documentation.sas.com/?docsetId=proc&docsetTarget=p1rwee205ou5qan1e66vyqsycmgk.htm&docsetVersion=9.4&locale=en
*/
proc fcmp outlib=work.funcs.subs;
	subroutine inverse(in, inv);
		outargs inv;

		if(in = 0) then do;
			put 'WARNING: Inverse of 0 is undefined.';
			inv = .;
		end;
			else inv = 1/in;
	endsub;
run;

data inverse;
	call inverse(10, inv);
	output;
	call inverse(0, inv);
	output;
run;

/********* Example 4: Loading multiple packages *********/

/* You can call and load multiple function families */
options cmplib=(work.funcs.time
				work.funcs.string 
				work.funcs.subs
			   );

/* FCMP can also do much more, like python functions and C structures. Check out the documentation
   for additional information. Happy coding!

   https://documentation.sas.com/?docsetId=proc&docsetTarget=n0pio2crltpr35n1ny010zrfbvc9.htm&docsetVersion=9.4&locale=en
*/
