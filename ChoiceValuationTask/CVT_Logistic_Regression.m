

%import the raw data
CVT = importdata('CVT_SHORTENED_S.xlsx');
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
    


%Find column names and column locations (because the original file has 2
%extra rows, start at row 3. (These two rows could be deleted but the
%original intention was to be able to run the excel file without much cleaning)
TextColumn = CVT.textdata(3,:);

%Header locations (HL) for each column needed for POE analysis
HL_Subject = find(strcmp(TextColumn,'Subject'));
HL_Session = find(strcmp(TextColumn,'Session'));
HL_Group = find(strcmp(TextColumn,'Group'));
HL_ArrowKeyResp = find(strcmp(TextColumn,'TestChoice.RESP'));
HL_CompLocation = find(strcmp(TextColumn,'CompLocation'));
HL_RT_GameSELF = find(strcmp(TextColumn,'TestSelfGame.RT'));
HL_RT_GameCOMP = find(strcmp(TextColumn,'TestCompGame.RT'));
HL_RewardLeft = find(strcmp(TextColumn,'RewardLeft'));
HL_RewardRight = find(strcmp(TextColumn,'RewardRight'));


%Make new column (NC) names to later be placed to the right of existing columns
NC_Choice_COMP = length(TextColumn) +1;
NC_Choice_SELF = length(TextColumn) +2;
NC_Points_COMP = length(TextColumn) +3;
NC_Points_SELF = length(TextColumn) +4;
NC_ExpectValue = length(TextColumn) +5;
NC_Anchor_COMP = length(TextColumn) +6;
NC_Anchor_SELF = length(TextColumn) +7;
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%separate by group
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Find all possible subject Numbers
SArray = unique(CVT.data(:,HL_Subject));

%Remove data that is impossible to calculate
RemoveDataListing = [10,22];

RemoveArray = any(SArray == RemoveDataListing,2);
SArray = SArray(~RemoveArray);


CutGroupPrompt = input('Which group would you like to run?\n 1. Younger Adults (REWARDED)\n 2. Healthy Older Adults\n 3. PD Patients\n 4. Younger Adults (NO REWARD)\n 5. All\n');
if CutGroupPrompt ~= 5
    for i = 1:length(SArray)
        IndvSub = (CVT.data(:,HL_Subject) == SArray(i));
        SubjectRow  = find(IndvSub);
        CutGroup(i) = (CVT.data(SubjectRow(1),HL_Group) == CutGroupPrompt);
    end
    SArray = SArray(CutGroup);
end



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%clean up data and combine columns
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




for Trial = 4:length(CVT.textdata);
    %disregard practice and survey trials, delete them later. RT_GameSELF 
    %is just a dummy variable that doesn't exist for practice
    if isnan(CVT.data(Trial-3,HL_RT_GameSELF));
        CVT.data(Trial-3,NC_Choice_COMP:NC_Anchor_SELF) = NaN;

    else 
        %check if Computer option was chosen which will be used for logistical
        %regression
        if  ((strcmp( CVT.textdata(Trial,HL_ArrowKeyResp) , {'{RIGHTARROW}'}) && strcmp(CVT.textdata(Trial,HL_CompLocation) , {'RIGHT'})) || (strcmp(CVT.textdata(Trial,HL_ArrowKeyResp),{'{LEFTARROW}'}) && strcmp( CVT.textdata(Trial,HL_CompLocation),{'LEFT'}))); 
        %Make two new columns saying which option was chosen, 
        %0= not chosen, 1 = chosen
            CVT.data(Trial-3,NC_Choice_COMP) = 1;
            CVT.data(Trial-3,NC_Choice_SELF) = 0;
        else
            CVT.data(Trial-3,NC_Choice_COMP) = 0;
            CVT.data(Trial-3,NC_Choice_SELF) = 1;
        end
        
         %Reorganize raw data to show all Computer points or Self points in
         %one column.
        if strcmp( CVT.textdata(Trial,HL_CompLocation),{'LEFT'});
            CVT.data(Trial-3,NC_Points_COMP) = CVT.data(Trial-3,HL_RewardLeft);
            CVT.data(Trial-3,NC_Points_SELF) = CVT.data(Trial-3,HL_RewardRight);
        else
            CVT.data(Trial-3,NC_Points_COMP) = CVT.data(Trial-3,HL_RewardRight);
            CVT.data(Trial-3,NC_Points_SELF) = CVT.data(Trial-3,HL_RewardLeft);
        end
        
            
        %Make another column showing what the expected value for picking 
        %that option was compared to the other option in reference to Self 
        %choice (if 10 vs. 12 is shown and the person chose 12 which was the
        %Self choice the expected value would be -2, this method is used for
        %the logistical regression)
        CVT.data(Trial-3,NC_ExpectValue) = CVT.data(Trial-3,NC_Points_COMP) - CVT.data(Trial-3,NC_Points_SELF);
        
        %Finally for data reorganization, make 2 columns showing if Computer
        %was the 10 point anchor or Self was. If both are 10, neither is
        %the anchor
        if CVT.data(Trial-3,NC_Points_COMP) == 10;
            if CVT.data(Trial-3,NC_Points_SELF) == 10;
                CVT.data(Trial-3,NC_Anchor_COMP) = 0;
                CVT.data(Trial-3,NC_Anchor_SELF) = 0;
            else
                CVT.data(Trial-3,NC_Anchor_COMP) = 1;
                CVT.data(Trial-3,NC_Anchor_SELF) = 0;
            end
        else
            if CVT.data(Trial-3,NC_Points_SELF) == 10;
                CVT.data(Trial-3,NC_Anchor_COMP) = 0;
                CVT.data(Trial-3,NC_Anchor_SELF) = 1;
            end
        end
            
    end
   
   
end

%delete Practice trials
NanRows = isnan(CVT.data(:,NC_Anchor_SELF));
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
ExpectedValue = -10:2:10;
POELine(1:11) = .5;

%Ask what graphs would like to be presented
DispGraphQues= input('What graphs do you want to see?\n 1. Only Subjects\n 2. Only Aggregated POE\n 3. All Graphs\n 4. None\n');
%Get POE and Graphs for each person
for SASubject = 1:length(SArray)
   
    %find subjects
    IndvSub = (CVTclean(:,1) == SArray(SASubject));
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
    
    %Separate by Anchor
%     AnchComp = CVTclean(SubjectRow,NC_Anchor_COMP);
%     SubAnchComp = find(AnchComp);
%     AnchSelf = CVTclean(SubjectRow,NC_Anchor_SELF);
%     SubAnchSelf = find(AnchSelf);

    AnchComp = logical(CVTclean(SubjectRow,NC_Anchor_COMP));
    SubAnchComp = SubjectRow(AnchComp);
    AnchSelf = logical(CVTclean(SubjectRow,NC_Anchor_SELF));
    SubAnchSelf = SubjectRow(AnchSelf);
    
%     AnchComp = logical(CVTclean(SubjectRow,NC_Anchor_COMP));
%     AnchComp = SubjectRow(AnchComp);
%     AnchSelf = logical(CVTclean(SubjectRow,NC_Anchor_SELF));
%     AnchSelf = SubjectRow(AnchSelf);
    
    %do Betas for split anchors
    [Beta_Comp, DEV_Comp, STATS_Comp] = glmfit(CVTclean(SubAnchComp,NC_ExpectValue),CVTclean(SubAnchComp,NC_Choice_SELF),'binomial');
    [Beta_Self, DEV_Self, STATS_Self] = glmfit(CVTclean(SubAnchSelf,NC_ExpectValue),CVTclean(SubAnchSelf,NC_Choice_SELF),'binomial');
    %also do Linear Regression
    LinearReg_COMP = fitlm(CVTclean(SubAnchComp,NC_ExpectValue),CVTclean(SubAnchComp,NC_Choice_SELF),'linear');
    LinearReg_SELF = fitlm(CVTclean(SubAnchSelf,NC_ExpectValue),CVTclean(SubAnchSelf,NC_Choice_SELF),'linear');
    LinearTable_Comp = table2array(LinearReg_COMP.Coefficients);
    LinearTable_Self = table2array(LinearReg_SELF.Coefficients);
    
    POE(SASubject,12) = (Beta_Comp(1)/(Beta_Comp(2)*-1));
    POE(SASubject,13:14) = Beta_Comp';
    POE(SASubject,15) = LinearTable_Comp(2,4);
    POE(SASubject,16) = STATS_Comp.p(2);
    POE(SASubject,17) = (Beta_Self(1)/(Beta_Self(2)*-1));
    POE(SASubject,18:19) = Beta_Self';
    POE(SASubject,20) = LinearTable_Self(2,4);
    POE(SASubject,21) = STATS_Self.p(2);
    
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
        axis([-10,10,-.1,1.1]);
        line([POE(SASubject,4) POE(SASubject,4)],get(hax,'YLim'),'Color',[.5 .5 .5])
        hold off
        
        legend('Predicted choice','Cross the 50/50 mark','Point of Equivalence')
        xlabel('COMPUTER Points Minus SELF Points')
        ylabel('Propensity to Choose SELF Option')
    end
end

%Preallocation
AveragedEV = zeros(2,11);

%get averaged POE and put it in POE matrix 
AveragedPOE = mean(POE(:,4));
POE(length(SArray)+2,4) = AveragedPOE;

%Get average choice propensity for computer at each Expected Value for
%Computer option
for AEVLoop = 1:11
    AveragedEV(1,AEVLoop)= mean(EVPoint(:,AEVLoop));
    AveragedEV(2,AEVLoop)= std(EVPoint(:,AEVLoop))/sqrt(length(EVPoint(:,AEVLoop)));
end

% check to see if aggregated graph is needed
if DispGraphQues == 2 || DispGraphQues == 3
    %plot the data
    figure(length(SArray)+1)
    hax=axes;
    
    hold on
    title('Averaged over all POE');
    plot(ExpectedValue,AveragedEV(1,:),'g-');
    plot(ExpectedValue,POELine,'b--');
    axis([-10,10,-.1,1.1]);
    line([AveragedPOE AveragedPOE],get(hax,'YLim'),'Color',[.5 .5 .5]);
    er = errorbar(ExpectedValue,AveragedEV(1,:),AveragedEV(2,:));
    er.Color = [0,0,0];
    er.LineStyle = 'none';
    line([AveragedPOE AveragedPOE],get(hax,'YLim'),'Color',[.5 .5 .5])
    hold off

    legend('Predicted choice','Cross the 50/50 mark','Point of Equivalence')
    xlabel('COMPUTER Points Minus SELF Points')
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
POEtable.Properties.VariableNames = {'Subject','Group','Session','POE','BetaConstant','BetaX','PValue_for_Linear_Regression','PValue_for_Logistical_Regression','SE_of_LogReg','DF','DEV','COMP_Anchor_POE','COMP_Anchor_BetaConstant','COMP_Anchor_BetaX','COMP_Anchor_PVal_Lin','COMP_Anchor_PVal_Log','SELF_Anchor_POE','SELF_Anchor_BetaConstant','SELF_Anchor_BetaX','SELF_Anchor_Pval_Lin','SELF_Anchor_PVal_Log'}

%close all the graphs but do not do so until user is ready
CloseQuestion = input('press 1 to close all figures\n');
if CloseQuestion == 1;
    close all;
end

