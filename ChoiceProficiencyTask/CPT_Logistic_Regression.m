%%%% This is a program to quick run a logistic and linear regression to
%%%% find a person's Point of Equivalence or the point in which someone
%%%% will choose the COMPUTER and SELF option equally. The task is the
%%%% Choice Valuation Task run in Pavlovia and this program was retrofitted
%%%% from a similar program that worked for the E-prime version. As such
%%%% some parts may seem superfluous since I left a lot in. 
%%%% -Eric Chantland



%import the raw data
CVT = importdata('CPT_Analysis_SHORTENED_S.xlsx');
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Find column location for needed data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%shorten the columns to match with data (this is necessary if the full file
%is used)
col_num = size(CVT.data);
col_text = size(CVT.textdata);
if col_num(2) < col_text(2);
    col_diff = col_text(2) - col_num(2)
    CVT.textdata = CVT.textdata(:,col_diff+1:end);
end
    
%Find Column names and column locations
TextColumn = CVT.textdata(1,:);

%Header locations (HL) for each column needed for POE analysis
HL_Subject = find(strcmp(TextColumn,'SubjectRedone'));
HL_Session = find(strcmp(TextColumn,'Session'));
HL_Group = find(strcmp(TextColumn,'group'));
HL_ArrowKeyResp = find(strcmp(TextColumn,'Choice_Left_or_Right'));
HL_CompLocation = find(strcmp(TextColumn,'Location_COMP'));
HL_RT_Game = find(strcmp(TextColumn,'RT_Choice'));
HL_ProbLeft = find(strcmp(TextColumn,'Prob_Left_Concatenated'));
HL_ProbRight = find(strcmp(TextColumn,'Prob_Right_Concatenated'));
HL_PerceivedProf = find(strcmp(TextColumn,'PerceivedProf'));


%Make new column (NC) names to later be placed to the right of existing columns
NC_Choice_COMP = length(TextColumn) +1;
NC_Choice_SELF = length(TextColumn) +2;
NC_Prob_COMP = length(TextColumn) +3;
NC_Prob_SELF = length(TextColumn) +4;
NC_ExpectValue = length(TextColumn) +5;
%For anchoring example, see Psychopy version of CVT,
%LogisticAnalysisBeta_PsychoPy.m


%Find all non-NaN possible subject numbers
SArray = unique(CVT.data(:,HL_Subject));
SArray = SArray(~isnan(SArray));

%Subjects gave what they believed their chance of getting the trials
%correct when they were in control (SELF Trials). This prompt asks whether analysis
%should be used with this perceived proficiency or just use 50%
PercievedProfQues= input('Do you want to the perceived proficiency subjects gave instead of 50%?\n 1. No\n 2. Yes\n');



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%clean up data and combine columns
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




for Trial = 2:length(CVT.textdata);
    %disregard practice and survey trials, delete them later. RT_GameSELF 
    %is just a dummy variable that doesn't exist for practice
    if isnan(CVT.data(Trial-1,HL_RT_Game));
        CVT.data(Trial-1,NC_Choice_COMP:NC_ExpectValue) = NaN;

    else 
        %check if Computer option was chosen which will be used for logistical
        %regression
        if  ((strcmp( CVT.textdata(Trial,HL_ArrowKeyResp) , {'right'}) && strcmp(CVT.textdata(Trial,HL_CompLocation) , {'right'})) || (strcmp(CVT.textdata(Trial,HL_ArrowKeyResp),{'left'}) && strcmp( CVT.textdata(Trial,HL_CompLocation),{'left'}))); 
        %Make two new columns saying which option was chosen, 
        %0= not chosen, 1 = chosen
            CVT.data(Trial-1,NC_Choice_COMP) = 1;
            CVT.data(Trial-1,NC_Choice_SELF) = 0;
        else
            CVT.data(Trial-1,NC_Choice_COMP) = 0;
            CVT.data(Trial-1,NC_Choice_SELF) = 1;
        end
        
         %Reorganize raw data to show all Computer probability or Self probability in
         %one column.
        if strcmp( CVT.textdata(Trial,HL_CompLocation),{'left'});
            CVT.data(Trial-1,NC_Prob_COMP) = CVT.data(Trial-1,HL_ProbLeft);
            CVT.data(Trial-1,NC_Prob_SELF) = CVT.data(Trial-1,HL_ProbRight);
        else
            CVT.data(Trial-1,NC_Prob_COMP) = CVT.data(Trial-1,HL_ProbRight);
            CVT.data(Trial-1,NC_Prob_SELF) = CVT.data(Trial-1,HL_ProbLeft);
        end
        
        %redoes SELF probability to perecieved proficiency if prompt is
        %chosen yes
        if PercievedProfQues == 2;
            CVT.data(Trial-1,NC_Prob_SELF) = CVT.data(Trial-1,HL_PerceivedProf);
        end
        
        
        %Make another column showing what the expected value for picking 
        %that option was compared to the other option in reference to Self 
        %choice (if 10 vs. 12 is shown and the person chose 12 which was the
        %Self choice the expected value would be -2, this method is used for
        %the logistical regression)
        CVT.data(Trial-1,NC_ExpectValue) = CVT.data(Trial-1,NC_Prob_COMP) - CVT.data(Trial-1,NC_Prob_SELF);
        
            
    end
   
   
end

%delete Practice trials
NanRows = isnan(CVT.data(:,end));
CVTclean = CVT.data(~NanRows,:);



%%
%Preallocation to save on speed
EVPoint = zeros(length(SArray),11);
POE = zeros(length(SArray),4);
BetaStore =  zeros(2,length(SArray));



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Graph the program and get POE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%used for graphing
ExpectedValue = -50:10:50;
POELine(1:11) = .5;

%Ask what graphs would like to be presented
DispGraphQues= input('What graphs do you want to see?\n 1. Only Subjects\n 2. Only Aggregated POE\n 3. All Graphs\n 4. None\n');
%Get POE and Graphs for each person
for SASubject = 1:length(SArray)
   
    %find subjects
    IndvSub = (CVTclean(:,HL_Subject) == SArray(SASubject));
    SubjectRow  = find(IndvSub);

    
    %Get Betas through logistical Regression
    [Beta, DEV, STATS] = glmfit(CVTclean(SubjectRow,NC_ExpectValue),CVTclean(SubjectRow,NC_Choice_SELF),'binomial');
    %also do Linear Regression
    LinearReg = fitlm(CVTclean(SubjectRow,NC_ExpectValue),CVTclean(SubjectRow,NC_Choice_SELF),'linear');
    LinearTable = table2array(LinearReg.Coefficients);
    

    
    %put Subject next to POE and Beta in one matrix for ease of checking
    POE(SASubject,1) = SArray(SASubject);
    POE(SASubject,2) = CVTclean(SubjectRow(1),HL_Group);
    %Implement sessions later
    POE(SASubject,3) = CVTclean(SubjectRow(1),HL_Session);
    POE(SASubject,4) = (Beta(1)/(Beta(2)*-1));
    POE(SASubject,5:6) = Beta';
    POE(SASubject,7) = LinearTable(2,4);
    POE(SASubject,8) = STATS.p(2);
    POE(SASubject,9) = STATS.se(2);
    POE(SASubject,10) = STATS.dfe;
    POE(SASubject,11) = DEV;
    

        %Make each point on the X-axis for each subject
    for EVCycle = 1:11
        EVPoint(SASubject,EVCycle) = (exp(Beta(1)+Beta(2)* ExpectedValue(EVCycle))/(1+exp(Beta(1)+Beta(2)* ExpectedValue(EVCycle))));
    end
    
    %check if we need to display all subject's graphs
    if DispGraphQues == 1 || DispGraphQues == 3
        %plot for each person
        figure(SASubject)
        hax=axes;
        hold on
        title(SArray(SASubject))
        plot(ExpectedValue,EVPoint(SASubject,:),'g-')
        plot(ExpectedValue,POELine,'b--')
        axis([-50,50,-.1,1.1]);
        line([POE(SASubject,4) POE(SASubject,4)],get(hax,'YLim'),'Color',[.5 .5 .5])
        hold off
        
        legend('Predicted choice','Cross the 50/50 mark','Point of Equivalence')
        xlabel('COMPUTER Chance Minus SELF Chance')
        ylabel('Propensity to Choose SELF Option')
    end
end

%Preallocation
AveragedEV = zeros(2,11);

%get averaged POE and put it in POE matrix 
AveragedPOE = mean(POE(:,4));
POE(length(SArray)+2,4) = AveragedPOE;

%Get average choice propensity for computer at each proficiency for
%Computer option
for AEVLoop = 1:11
    AveragedEV(1,AEVLoop)= mean(EVPoint(:,AEVLoop));
    AveragedEV(2,AEVLoop)= std(EVPoint(:,AEVLoop))/sqrt(length(EVPoint(:,AEVLoop)));
end

% check to see if aggregated graph is needed
if DispGraphQues == 2 || DispGraphQues == 3
    %plot the data for aggregated POE
    figure(length(SArray)+1)
    hax=axes;
    
    hold on
    title('Averaged over all POE');
    plot(ExpectedValue,AveragedEV(1,:),'g-');
    plot(ExpectedValue,POELine,'b--');
    axis([-50,50,-.1,1.1]);
    line([AveragedPOE AveragedPOE],get(hax,'YLim'),'Color',[.5 .5 .5]);
    er = errorbar(ExpectedValue,AveragedEV(1,:),AveragedEV(2,:));
    er.Color = [0,0,0];
    er.LineStyle = 'none';
    line([AveragedPOE AveragedPOE],get(hax,'YLim'),'Color',[.5 .5 .5])
    hold off

    legend('Predicted choice','Cross the 50/50 mark','Point of Equivalence')
    xlabel('COMPUTER Chance Minus SELF Chance')
    ylabel('Propensity to Choose SELF Option')
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Save POE and show POE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%saves POE matrix to an accessable file to export cells at my leisure.
filename = 'POE.mat';
save(filename,'POE');

%show Point of Equivalence table as reference when looking at the graph
POEtable = array2table(POE);
POEtable.Properties.VariableNames = {'Subject','Group','Session','POE','BetaConstant','BetaX','PValue_for_Linear_Regression','PValue_for_Logistical_Regression','SE_of_LogReg','DF','DEV'}

%close all the graphs but do not do so until user is ready
CloseQuestion = input('press 1 to close all figures\n');
if CloseQuestion == 1;
    close all;
end



