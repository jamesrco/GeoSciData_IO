% Exoenzyme_plate_data_read_Tecan_F200.m

% Created 13 Nov 2013 by J.R.C.
% Modified 19 Jan 14 by J.R.C. to read in LMG 1401 cruise data
% Modified 30 Nov 15 by J.R.C. to clean-up code & clarify comments for
% upload to GitHub

% Purpose: Reads, stores to file, and interactively calculates rates of bacterial
% exoenzyme activities using fluoresence data from 96-well plate
% incubations with fluorogenic substrates. Currently configured to parse
% data in .txt files from a Tecan F200 plate reader.

% For a good introduction to the use of bacterial exoenzyme activity assays
% in aquatic and marine environments, see H. Hoppe, 1993, "Use of Fluorogenic
% Model Substrates for Extracellular Enzyme Activity (EEA) Measurement of
% Bacteria," in Kemp, P. F., and others, eds., Handbook of Methods in
% Aquatic Microbial Ecology, pp. 423-431.

% The specific protocol for preparation, incubation, and reading of plates
% used to generate data that can be processed using the current version of
% the script has been uploaded to the same GitHub repository where this
% script is maintained; this protocol was used in Edwards et al., 2011, "Rapid
% microbial respiration of oil from the Deepwater Horizon spill in offshore
% surface waters of the Gulf of Mexico," Environ. Res. Lett. 6:035301

% Dependencies:
%
%  1. Plate reader data files containing sample data and standard curve
%  data. These should be saved to subdirectories Plate_data and
%  Standard_curves, within the master data directory that the user can
%  specify below.
%
%  2. A plate reader log (Excel file) containing metadata, which will serve
%  as the bridge between the plate data files and standard curve files.
%  This must be maintained in a specific format to work with the script. An
%  example is provided in the GitHub repo where this script is maintained.
%
%  3. The MATLAB script nlleasqr.m, which performs non-linear least
%  squares regression of data to obtain best-fit parameters for a given
%  function
%
%  4. The MATLAB file "fluorcurves_cubicfitfunc.m," which specifies the function
%  for which values are obtained below using nlleasqr.m (used for
%  fitting of standard curves)
%
%  5. The MATLAB script linfit.m, which performs standard Type 1 linear
%  regression of data; this is invoked repeatedly during interactive
%  calculation of the enzyme activity rates, below.
%
%  An example log file and the file fluorcurves_cubicfitfunc.m are archived
%  along with the most current version of this script to the GitHub sub-
%  repository https://github.com/jamesrco/GeoSciData_IO/ExoenzymeHydroCalc
%
%  The other two MATLAB scripts are archived to
%  https://github.com/jamesrco/dependencies-useful-scripts/
%
%  Several "example" Tecan 200 plate reader data files containing real
%  sample data and standard curve data from the LMG 1401 cruise have been
%  uploaded to the same sub-repository
%
%  Assumptions:
%
%  1. All files containing sample data have been saved with a timestamp
%  filename corresponding to the correct timestamp in the sample log,
%  followed by "_MUF_AMC_substrates.txt"
%
%  An acceptable data file name would be '20140502_1345_MUF_AMC_substrates.txt'
%
%  2. All files containing standard curve data have been saved according to
%  the same convention vis-a-vis the sample log, but end in
%  "_MUF_AMC_standard_curve.txt"
%
%  3. User has specified the correct mass, in mg, of the substrates he or
%  she added (see below)

close all;
clear all;
clf;

%% User specify file paths, other required inputs

LogFile = 'LMG 1401 Tecan F200 Log - MUF and AMC Enzyme Assays.xlsx'; % file name of your Excel log file

NameOfFile = 'LMG1401_assaydata'; % base name of .mat and .csv files to which data are to be written upon completion

% this is also the base name of the .mat file that should already exist if beginning to process data at a point other than row 10 of the log spreasheet (see option below)

Tecanfiles_directory='Tecan_F200_data/'; % specify the directory into which you've saved the data files from the plate reader. Within this directory should two folders that actually contain the files, "Plate_data" and "Standard_curves"

% Information required to calculate standard curve:

MUF_mass = 12.91; % exact mass of 4-MUF, in mg, that you actually added to 12.5 mL Milli-Q
AMC_mass = 11.33; % exact mass of AMC, in mg, that you actually added to 12.5 mL DMSO

%% Provide feedback to user, prompt for start row (if not starting from first entry in sample log)

disp([char(10) 'Exoenzyme_plate_data_read_Tecan_F200.m: Reads and stores to file fluoresence data from Tecan F200 plate reader .txt output.'...
' Correlates and collates data in the Tecan output files for each enzyme assay incubation, using the metadata and sample read times in the user-specific sample log'...
char(10) char(10) 'Your files will be read out of: ' Tecanfiles_directory char(10)...
char(10) 'Hit enter to begin...' char(10)]);

pause;

disp(['To begin loading and analyzing data from the sample log at the first log entry (row 11 in the Excel spreadsheet), simply hit enter.'...
    ' If you wish to begin loading data at a different point and then append to the existing dataset, enter the row of the log entry at which you''d like to start:' char(10)]);

startrow=input('');

if isempty(startrow) % if no input, start at the beginning
    startrow=10;
else % start where user told it to, and load existing data into memory
    load(strcat(Tecanfiles_directory,NameOfFile));
    existing_results=results;
    clear results;
    disp(char(10));
end

Sampledata_directory='Plate_data/';

Standardcurves_directory='Standard_curves/';

Sampledata_filelist=strcat(Tecanfiles_directory,Sampledata_directory,'*MUF_AMC_substrates.txt'); % query to find only MUF and AMC sample data

Standardcurves_filelist=strcat(Tecanfiles_directory,Standardcurves_directory,'*MUF_AMC_standard_curve.txt'); % query to find only MUF and AMC standard curve data

MUFAMC_sample_datafiles = dir(Sampledata_filelist); % execute query to find only sample data files 
MUFAMC_stdcurve_datafiles = dir(Standardcurves_filelist); % execute query to find only standard curve data files

%% First, read in relevant information from the sample log

disp(['Reading in relevant information from the sample log, starting at row ' num2str(startrow) '...' char(10)]);

[num_log txt_log raw_log] = xlsread(strcat(Tecanfiles_directory,'LMG 1401 Tecan F200 Log - MUF and AMC Enzyme Assays.xlsx'),'Sample Log');

% first, fields that don't require much conversion

% LMG 1401 fields only
log.CTDID = cell2mat(raw_log(startrow:end,1));
log.LTERgridX = cell2mat(raw_log(startrow:end,3));
log.LTERgridY = cell2mat(raw_log(startrow:end,2));

log.depth = cell2mat(raw_log(startrow:end,4));
log.samtemp = cell2mat(raw_log(startrow:end,5));
log.inctemp = cell2mat(raw_log(startrow:end,6));
log.colltime = cell2mat(raw_log(startrow:end,7));
log.colltime(find(isfinite(log.colltime)))=x2mdate(log.colltime(find(isfinite(log.colltime))));
log.scurvetime = cell2mat(raw_log(startrow:end,9));
log.scurvetime(find(isfinite(log.scurvetime)))=x2mdate(log.scurvetime(find(isfinite(log.scurvetime))));
log.t0 = cell2mat(raw_log(startrow:end,10));
log.t0(find(isfinite(log.t0)))=x2mdate(log.t0(find(isfinite(log.t0))));
log.t1 = cell2mat(raw_log(startrow:end,11));
log.t1(find(isfinite(log.t1)))=x2mdate(log.t1(find(isfinite(log.t1))));
log.t2 = cell2mat(raw_log(startrow:end,12));
log.t2(find(isfinite(log.t2)))=x2mdate(log.t2(find(isfinite(log.t2))));
log.t6 = cell2mat(raw_log(startrow:end,13));
log.t6(find(isfinite(log.t6)))=x2mdate(log.t6(find(isfinite(log.t6))));
log.t12 = cell2mat(raw_log(startrow:end,14));
log.t12(find(isfinite(log.t12)))=x2mdate(log.t12(find(isfinite(log.t12))));
log.t18 = cell2mat(raw_log(startrow:end,15));
log.t18(find(isfinite(log.t18)))=x2mdate(log.t18(find(isfinite(log.t18))));
log.t24 = cell2mat(raw_log(startrow:end,16));
log.t24(find(isfinite(log.t24)))=x2mdate(log.t24(find(isfinite(log.t24))));

% now, load and convert fields that have letter or mixed alphanumeric data into
% numerical indices

% for fields that have blanks, must keep track of where these blank values
% are in the input cell array and then turn them into NaNs once we convert
% that field into a vector

% plate row

platerow_raw = txt_log(startrow:end,8);
platecols = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'};
for i=1:length(platecols)
    ind_thiscol=strmatch(platecols(i),platerow_raw);
    log.platerow(ind_thiscol,1)=i;
end
clear i ind_thiscol;

disp(['Based on the provided start point, found ' num2str(length(log.CTDID)) ' entries in log corresponding to ' ...
    num2str(length(log.CTDID)) ' samples or separate plate rows.' char(10)...
    char(10) 'Enter to continue and generate the necessary standard curve fits...' char(10)]);
pause;

%% Now, generate standard curve fits for each standard curve listed in the log

% first calculate concentrations in each well of plate used for standard curve,
% assuming serial dilution was performed correctly

MUF_std = ((MUF_mass/176.17)/13.05)*1000; % conc of undiluted 4-MUF standard, mM

AMC_std = ((AMC_mass/175.18)/12.99)*1000; % conc of undiluted AMC standard, mM

% calculate concentrations according to serial dilution

c_i = MUF_std*200*(1/10^6)*(1/20)*1000; % concentration of first well of serial dilution, mM
for i=1:12
    MUF_concs(1,i) = c_i;
    c_i=c_i/2;
end

clear i c_i;

c_i = AMC_std*200*(1/10^6)*(1/20)*1000; % concentration of first well of serial dilution, mM
for i=1:12
    AMC_concs(1,i) = c_i;
    c_i=c_i/2;
end

clear i c_i;

% now, load in the fluoresence data

stdcurve_list = unique(log.scurvetime); % get a list of all the standard curves needed to proceed with data analysis

disp(['Found data for ' num2str(length(stdcurve_list)) ' separate standard curves.' char(10)...
    char(10) 'Enter to fit these data to a cubic function using nlleasqr...' char(10)]);
pause;

stdcurve_data=nan(length(stdcurve_list),33); % create a matrix where we'll store all the standard curve fit data

stdcurve_data(:,1)=stdcurve_list; 

for i=1:length(stdcurve_data(:,1))
    thiscurve=stdcurve_data(i,1);
    
    curvefile=strcat(Tecanfiles_directory,Standardcurves_directory,...
    datestr(thiscurve,'yyyymmdd_HHMM'),'_MUF_AMC_standard_curve.txt');

    raw_MUFdat = importdata(curvefile,'\t',31);
    stdcurve_data(i,2:13) = raw_MUFdat.data;  % load in MUF data
    raw_AMCdat = importdata(curvefile,'\t',57);    
    stdcurve_data(i,14:25) = raw_AMCdat.data; % load in AMC data
    
    figure(1);
    
    % first, fit data to a cubic function, using nlleasqr to obtain best-fit
    % parameter values
    
    pin = [150 -2600 17500 200]; % initial guesses for MUF
    [f_MUF,p_MUF,kvg_MUF,iter_MUF,corp_MUF,covp_MUF,covr_MUF,stdresid_MUF...
        ,Z_MUF,r2_MUF]=nlleasqr(MUF_concs',...
        stdcurve_data(i,2:13)',pin,'fluorcurves_cubicfitfunc');
    yf_MUF = fluorcurves_cubicfitfunc(MUF_concs,p_MUF);
    subplot(2,2,1);
    plot(MUF_concs,stdcurve_data(i,2:13),'o',MUF_concs,yf_MUF);
    xlabel('4-MUF concentration (mM)');
    ylabel('Fluoresence');
    pin = [85 -1300 14000 200]; % initial guesses for AMC
    [f_AMC,p_AMC,kvg_AMC,iter_AMC,corp_AMC,covp_AMC,covr_AMC,stdresid_AMC...
        ,Z_AMC,r2_AMC]=nlleasqr(AMC_concs',...
        stdcurve_data(i,14:25)',pin,'fluorcurves_cubicfitfunc');
    yf_AMC = fluorcurves_cubicfitfunc(AMC_concs,p_AMC);
    subplot(2,2,2);
    plot(AMC_concs,stdcurve_data(i,14:25),'o',AMC_concs,yf_AMC);
    xlabel('AMC concentration (mM)');
    ylabel('Fluoresence');
    
    % now, perform reverse cubic fit using nlleasqr (so we have parameters for an equation in a form that is actually useful to us)
    
    pin = [8e-14 -2.5e-9 8e-5 -.01]; % initial guesses for MUF
    [f_MUF_inv,p_MUF_inv,kvg_MUF_inv,iter_MUF_inv,corp_MUF_inv,...
        covp_MUF_inv,covr_MUF_inv,stdresid_MUF_inv...
        ,Z_MUF_inv,r2_MUF_inv]=nlleasqr(stdcurve_data(i,2:13)',MUF_concs',...
        pin,'fluorcurves_cubicfitfunc');
    yf_MUF_inv = fluorcurves_cubicfitfunc(stdcurve_data(i,2:13),p_MUF_inv); 
    subplot(2,2,3);
    plot(stdcurve_data(i,2:13),MUF_concs,'o',stdcurve_data(i,2:13),yf_MUF_inv);
    ylabel('4-MUF concentration (mM)');
    xlabel('Fluoresence');        
    pin = [3e-15 5e-10 7e-5 -.01]; % initial guesses for AMC
    [f_AMC_inv,p_AMC_inv,kvg_AMC_inv,iter_AMC_inv,corp_AMC_inv,covp_AMC,...
        covr_AMC_inv,stdresid_AMC_inv...
        ,Z_AMC_inv,r2_AMC_inv]=nlleasqr(stdcurve_data(i,14:25)',AMC_concs',...
        pin,'fluorcurves_cubicfitfunc');
    yf_AMC_inv = fluorcurves_cubicfitfunc(stdcurve_data(i,14:25),p_AMC_inv); 
    subplot(2,2,4);
    plot(stdcurve_data(i,14:25),AMC_concs,'o',stdcurve_data(i,14:25),yf_AMC_inv);
    ylabel('AMC concentration (mM)');
    xlabel('Fluoresence');        
    % store curve fit parameters to stdcurve_data matrix
    stdcurve_data(i,26:29)=p_MUF_inv';
    stdcurve_data(i,30:33)=p_AMC_inv';
    disp(['Statistics for fit of standard curve: ' datestr(thiscurve) char(10)...
        char(10) 'r^2 for 4-MUF fit      r^2 for AMC fit' char(10)...
        num2str(r2_MUF_inv) '          ' num2str(r2_AMC_inv) char(10) char(10)...
        'Enter to continue to next curve...' char(10)]);
        pause;
end
disp(['Curve fitting complete.' char(10)]);

clear i;

%% Next, match appropriate data files with standard curves, load and convert data

% working sequentially through the sample log, load in relevant data files,
% then compute concentrations using the applicable standard curve

% load data from Tecan data files, then convert values to concentrations 
% using appropriate standard curve, and finally populate matrices
% "assaydata.fluor" and "assaydata.conc" where each row in those matrices
% corresponds to a row in the sample log

disp(['Now, match appropriate data files with standard curves, load data, and convert'...
' fluoresence values to concentrations. Will store data to a new structure of arrays called "assaydata."'...
char(10) char(10) 'Enter to continue...' char(10)]);
pause;

for i=1:length(log.colltime)
    thisrow=log.platerow(i);
    MUFbutdata_row=31;  % set up some indexes so we can tell MATLAB
    MUFglucdata_row=64; % where to find the data for each assay type
    MUFPO4data_row=97;  % within the Tecan data file
    AMCleudata_row=130;

    thisscurve=log.scurvetime(i); % load the corresponding standard curve data
    ind_scurve=find(stdcurve_data(:,1)==thisscurve);
    p_MUF_inv=stdcurve_data(ind_scurve,26:29);
    p_AMC_inv=stdcurve_data(ind_scurve,30:33);
    readtimes=[log.t0(i) log.t1(i) log.t2(i) log.t6(i) log.t12(i) log.t18(i) log.t24(i)];
    assaydata.fluor(i,1:84)=NaN;
    assaydata.conc(i,1:84)=NaN;
    MUFbutinsertcol=1;
    MUFglucinsertcol=22;
    MUFPO4insertcol=43;
    AMCleuinsertcol=64;
    for j=1:length(readtimes)
        thisreadtime=readtimes(j);
        if isfinite(thisreadtime) % if this row of this plate was read at this time, then load data
            datafile=strcat(Tecanfiles_directory,Sampledata_directory,...
        datestr(thisreadtime,'yyyymmdd_HHMM'),'_MUF_AMC_substrates.txt');
    
            % load in "raw" (i.e., fluoresence data)
            
            raw_MUFbutdata_fluor = importdata(datafile,'\t',MUFbutdata_row);
            MUFbutdata_fluor = raw_MUFbutdata_fluor.data(thisrow,:);

            raw_MUFglucdata_fluor = importdata(datafile,'\t',MUFglucdata_row);
            MUFglucdata_fluor = raw_MUFglucdata_fluor.data(thisrow,:);

            raw_MUFPO4data_fluor = importdata(datafile,'\t',MUFPO4data_row);
            MUFPO4data_fluor = raw_MUFPO4data_fluor.data(thisrow,:);

            raw_AMCleudata_fluor = importdata(datafile,'\t',AMCleudata_row);
            AMCleudata_fluor = raw_AMCleudata_fluor.data(thisrow,:);

            MUFbutdata_conc=p_MUF_inv(1)*MUFbutdata_fluor.^3+p_MUF_inv(2)*...
                MUFbutdata_fluor.^2+p_MUF_inv(3)*MUFbutdata_fluor+p_MUF_inv(4);
            MUFglucdata_conc=p_MUF_inv(1)*MUFglucdata_fluor.^3+p_MUF_inv(2)*...
                MUFglucdata_fluor.^2+p_MUF_inv(3)*MUFglucdata_fluor+p_MUF_inv(4);
            MUFPO4data_conc=p_MUF_inv(1)*MUFPO4data_fluor.^3+p_MUF_inv(2)*...
                MUFPO4data_fluor.^2+p_MUF_inv(3)*MUFPO4data_fluor+p_MUF_inv(4);
            AMCleudata_conc=p_AMC_inv(1)*AMCleudata_fluor.^3+p_AMC_inv(2)*...
                AMCleudata_fluor.^2+p_AMC_inv(3)*AMCleudata_fluor+p_AMC_inv(4);
            
            % write both fluoresence and concentration values to respective matrices
            
            assaydata.fluor(i,MUFbutinsertcol:MUFbutinsertcol+2)=MUFbutdata_fluor;
            assaydata.fluor(i,MUFglucinsertcol:MUFglucinsertcol+2)=MUFglucdata_fluor;
            assaydata.fluor(i,MUFPO4insertcol:MUFPO4insertcol+2)=MUFPO4data_fluor;
            assaydata.fluor(i,AMCleuinsertcol:AMCleuinsertcol+2)=AMCleudata_fluor;
            assaydata.conc(i,MUFbutinsertcol:MUFbutinsertcol+2)=MUFbutdata_conc;
            assaydata.conc(i,MUFglucinsertcol:MUFglucinsertcol+2)=MUFglucdata_conc;
            assaydata.conc(i,MUFPO4insertcol:MUFPO4insertcol+2)=MUFPO4data_conc;
            assaydata.conc(i,AMCleuinsertcol:AMCleuinsertcol+2)=AMCleudata_conc;
        end
        
        % advance our insertion points so data from the next timepoint gets put in the correct columns
        MUFbutinsertcol=MUFbutinsertcol+3;
        MUFglucinsertcol=MUFglucinsertcol+3;
        MUFPO4insertcol=MUFPO4insertcol+3;
        AMCleuinsertcol=AMCleuinsertcol+3;
    end
end

clear i j;

%% Compute substrate hydrolysis rates interactively

% allow user to select the range of timepoints over which the regression
% should be run, after plotting the averaged concentrations for each
% timepoint

disp(['Data loaded and values converted to concentrations.' char(10) char(10) 'You can now proceed with'...
    ' interactive curve fitting to calculate enzyme hydrolysis rates. This program will'...
    ' plot the fluoresence timepoint data for each sample and each of the four assays. You'...
    ' must then select the range over which to calculate the rate of hydrolysis by linear regression.' char(10) char(10)...
    'Use the cursor to define the range of timepoints over which the substrate production rate appears linear.'...
    ' Select the first and last locations over which you wish to fit the regression line. The input function will accept two mouse clicks per subplot.'...
    ' This range will be used to calculate rate of hydrolysis by weighted linear least-squares regression.' char(10) char(10)...
    'If there''s no apparent trend and you don''t wish to calculate a rate,'...
    ' click twice in the plot to the right of the last data point. This will'...
    ' result in selection of no data points.' char(10) char(10) 'Error bars represent'...
    ' standard deviations of each set of triplicate readings. These standard deviations will be used as weights (i.e., uncertainties) to compute the error in regression parameters.' char(10) char(10) 'Enter to proceed...' char(10)]);
pause;

% first, calculate mean values at each timepoint from triplicates, along with std dev
for i=1:length(assaydata.conc(:,1)) % go line by line through the sample log
    tripcount=1;
    for j=1:28 % calculate mean values and std devs for each set of triplicates
        assaydata.mean(i,j)=mean(assaydata.conc(i,tripcount:tripcount+2));
        assaydata.stdev(i,j)=std(assaydata.conc(i,tripcount:tripcount+2));
        tripcount=tripcount+3;
    end
end
clear i j tripcount;

% now, make plots for each assay and ask user to choose timepoint range for
% regression

% set some variables for labeling points on plots
a = (1:7)'; b = num2str(a); c = cellstr(b); % labels for points on plot
dx = 0.05; dy = 0; % displacement so the text does not overlay the data points

current_results=nan(length(assaydata.mean(:,1)),8); % create destination table for results

for i=1:length(assaydata.mean(:,1))
    clf;
    figure(gcf());
    plotspan=[3 5 7;4 6 8;9 11 13;10 12 14];
    readtimes=[log.t0(i) log.t1(i) log.t2(i) log.t6(i) log.t12(i) log.t18(i) log.t24(i)];
    subplot(7,2,plotspan(1,:));
    but_means=assaydata.mean(i,1:7);
    but_devs=assaydata.stdev(i,1:7);
    errorbar(readtimes,but_means,but_devs,'o');
    ylabel('4-MUF-butyrate (mM)');
    text(readtimes+dx,but_means+dy,c);
    ax(1)=gca();
    set(ax(1),'XLim',[min(readtimes)-0.0000015e05 max(readtimes)+0.0000025e05]);
    subplot(7,2,plotspan(2,:));
    gluc_means=assaydata.mean(i,8:14);
    gluc_devs=assaydata.stdev(i,8:14);
    errorbar(readtimes,gluc_means,gluc_devs,'o');
    ylabel('4-MUF-alpha-D-glucopyranoside (mM)');
    text(readtimes+dx,gluc_means+dy,c);
    ax(2)=gca();
    set(ax(2),'XLim',[min(readtimes)-0.0000015e05 max(readtimes)+0.0000025e05]);
    subplot(7,2,plotspan(3,:));
    PO4_means=assaydata.mean(i,15:21);
    PO4_devs=assaydata.stdev(i,15:21);
    errorbar(readtimes,PO4_means,PO4_devs,'o');
    ylabel('4-MUF-PO4 (mM)');
    text(readtimes+dx,PO4_means+dy,c);
    ax(3)=gca();
    set(ax(3),'XLim',[min(readtimes)-0.0000015e05 max(readtimes)+0.0000025e05]);
    subplot(7,2,plotspan(4,:));
    leu_means=assaydata.mean(i,22:28);
    leu_devs=assaydata.stdev(i,22:28);
    errorbar(readtimes,leu_means,leu_devs,'o');
    ylabel('Leucine-MCA (mM)');
    text(readtimes+dx,leu_means+dy,c);
    ax(4)=gca();
    set(ax(4),'XLim',[min(readtimes)-0.0000015e05 max(readtimes)+0.0000025e05]);
    
    % put the proper title on the plot
        staID=log.CTDID(i);
        str1='Enzyme assay plate readings for:';
        str2=['CTD ' num2str(staID) ', depth ' num2str(log.depth(i)) ' m'];
        str3=['Collected at ' datestr(log.colltime(i))];
        str4=['Concentrations using standard curve: ' datestr(log.scurvetime(i))];
        str5=datestr(log.colltime(i));

    annotation('textbox', [0 0.9 1 0.1], ...
    'String', {str1;str2;str3;str4}, ...
    'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center','FontSize',14)
    disp(['Ready for input on currently displayed sample ' str5 ': Click twice with cursor in each plot of active figure, beginning with upper left panel, to define range for regression.' char(10) ]);
    % now, prompt user to select range for regression
    [xrange,yrange]=ginput(8);
    % now, figure out which points lie within the defined ranges and calculate rate
    disp(['Fit for sample ' str5 ':' char(10)]);
    assays={'4-MUF-but ' '4-MUF-gluc' '4-MUF-PO4 ' 'leu-AMC  '};
    disp(['Assay       prod rate    r^2      err est   rel std err']);
    disp(['            (mmol/L/d)            (mmol/L/d)' char(10)]);
    for j=1:4
        readtimes=[log.t0(i) log.t1(i) log.t2(i) log.t6(i) log.t12(i) log.t18(i) log.t24(i)];
        k=j+1*(j-1);
        l=j+6*(j-1)-1;
        ind_regpoints=find(readtimes>=xrange(k) & readtimes<=xrange(k+1));
        regminpt=min(ind_regpoints);
        regmaxpt=max(ind_regpoints);
        if isempty(ind_regpoints)
        disp([cell2mat(assays(j)) '  ' 'No regression calculated']);            
        else
        % use linfit to calculate best-fit linear regression parameters, using std devs of triplicate means as sy
        x=readtimes(regminpt:regmaxpt)';
        x(find(isnan(x)))=[];
        y=assaydata.mean(i,regminpt+l:regmaxpt+l)';
        y(find(isnan(y)))=[];
        sy=assaydata.stdev(i,regminpt+l:regmaxpt+l)';
        sy(find(isnan(sy)))=[];
        [a sa cov r]=linfit(x,y,sy);
        % evaluate the linear function at the selected timepoints
        yf=a(2)*x+a(1);
        % superimpose regression on plot
        subplot(7,2,plotspan(j,:));
        set(ax(j),'NextPlot','add');
        plot(x,yf,'r-');
        % display data to user
        disp([cell2mat(assays(j)) '  ' num2str(a(2)) '       ' num2str(r) '    '...
                num2str(sa(2)) '    ' num2str(sa(2)/a(2))]);
        % write to results table
        current_results(i,k:k+1)=[a(2) sa(2)]; % rate est and error in mmol/L/day
        end
    end
    disp(['Enter to continue to next sample...' char(10)]);
    pause;
end

%% Results file write

disp([char(10) 'Analysis complete. Results written to table. Click to write data to files and end script...']);

pause;

% first, a chance to convert units if desired

confactor=(10^6)/24; % 1e6/24 to get nmol/L/hr

converted_results=current_results*confactor;

% append new results to the existing results, if we started at a point other
% than row 10 of the log; otherwise, just write the results matrix from
% this script run to file

if startrow==10
    results=converted_results;
else
    results=existing_results;
    results((length(results(:,1))+1):(length(results(:,1))+length(converted_results(:,1))),1:8)=converted_results;
end

save(strcat(Tecanfiles_directory,NameOfFile),'results');

export_precision=10; % necessary otherwise timestamps won't be written correctly

% write data to file

headers_csv = ['4-MUF-buytrate prod rate (nmol/L/hr),4-MUF-butyrate prod rate uncertainty (nmol/L/hr),4-MUF-alpha-D-glucopyranoside prod rate (nmol/L/hr),4-MUF-alpha-D-glucopyranoside prod rate uncertainty (nmol/L/hr),4-MUF-PO4 prod rate (nmol/L/hr),4-MUF-PO4 prod rate uncertainty (nmol/L/hr),leu-MCA prod rate (nmol/L/hr),leu-MCA prod rate uncertainty (nmol/L/hr)'];
outid = fopen(strcat(Tecanfiles_directory,NameOfFile,'.csv'), 'w+');
fprintf(outid, '%s', headers_csv);
fclose(outid);
dlmwrite (strcat(Tecanfiles_directory,NameOfFile,'.csv'),results,'roffset',1,'-append','precision',export_precision);

disp([char(10) 'Results written to files "' NameOfFile '.mat" and "' NameOfFile '.csv."']);


