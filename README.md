# GeoSciData_IO
Various scripts for data input/output, massaging of oceanographic/meteorological data, and rudimentary follow-on analysis. Mostly useful for earth scientists/oceanographers (and maybe biologists), since I'm an oceanographer.

Brief descriptions of each:

1. [Convert_PALWx.R](https://github.com/jamesrco/GeoSciData_IO/blob/master/Convert_PALWx.R): Parses separate tab-delimited text files containing one- and two-minute meteorological data from the weather station at Palmer Station, Antarctica. Will read in a large number of files, identify whether they contain one- or two-minute interval data, and then join them together in a single data store that can be easily manipulated. Converts timestamps to format R can deal with. Also includes a handy implementation of the R package "RSEIS" to calculate year-agnostic decimal julian days for each set of observations based on timestamps. This is useful if you'd like to plot time series data from multiple years on a set of common axes, or otherwise manipulate the observations by day/month/hour, where the year isn't important. Includes some basic code snippets for subsetting.
