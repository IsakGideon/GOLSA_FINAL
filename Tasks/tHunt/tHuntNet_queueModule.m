% runs small 6-state environment simulation
clear all
%%%%%%%%%%%%%%%
% Basic Setup %
%%%%%%%%%%%%%%%
NEW_NETWORK = 1;
SET_WEIGHTS = 1; %initialize weights to correct values
rng(45);

global dt endTime t 
dt=.05;


if NEW_NETWORK
    clearvars -except NEW_NETWORK SET_WEIGHTS dt endTime t
    [e, n] = create_tHuntNet_queue(SET_WEIGHTS);
elseif ~exist('n')
    error('Network has not been initialized. Set NEW_NETWORK=1')
end


load('stateSpaces/tHunt_weights.mat') %used to compare with model weights to assess learning



%%%%%%%%%%%%%%%%
% Run Settings %
%%%%%%%%%%%%%%%%
MAX_TIME = 600; %maximum trial length
MAX_STUCK_TIME = 40; %maximum time to have a goal and not move
NUM_TRIALS = 1;
TEXT_OUTPUT = 1;

SETUP_LIST = [1, 3 ,4]; %column 1: starting states; column 2: goals
% SETUP_LIST = [1, 2 ]; %column 1: starting states; column 2: goals

REPEAT_MODE = 2;  %1 = alternate, 2 = repeat, 3 = first only
%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%
% Set up batch %
%%%%%%%%%%%%%%%%

numSetups = size(SETUP_LIST, 1);
switch REPEAT_MODE
    case 1 %alternate rows of setupList one at time
        setupIndices = repmat(1:numSetups, 1, NUM_TRIALS/numSetups+1);
        
    case 2 %do each row of setupList a specified number of times before repeating
        numRepeats = 4;
        setupIteration = reshape(repmat(1:numSetups, numRepeats, 1), 1, numRepeats*numSetups);
        setupIndices = repmat(setupIteration, 1, ceil(NUM_TRIALS / (numRepeats * numSetups)));
        setupIndices = setupIndices(1:NUM_TRIALS);
        
    case 3 %only use first row
         setupIndices = ones(1,NUM_TRIALS);
end

%batchResults checks whether goal is reached, how long it takes, and how far from ideal
%the goalGradient->goalGradient, state->adjacent, and transition->motor weights are;
%6th column is the total error
batchResults = nan(NUM_TRIALS, 6); 

% n.logAll({'layers', 'nodes'});
n.logAll();

%the first list of items will be displayed in real time
%the second list will be projected onto an environment of the dimenions 
%specified by the third argument
% n.set_display({'gradient', 'p_gradient_gradient'},{'state'}, [2,3]);


%%%%%%%%%%%%%%
% Run Trials %
%%%%%%%%%%%%%%


for trial_i = 1:NUM_TRIALS
    endTime=MAX_TIME;
    t = dt;
    tSinceMove = -1.5;
    moved = 0;
    exploreRate = 0;
    goalTime=[];
    

    startingState = SETUP_LIST(setupIndices(trial_i), 1);
    goal = SETUP_LIST(setupIndices(trial_i), 2:end);
 
    lastState = startingState;

    n.reset();
    e.reset(startingState); 
    n.setNode('n_env', e.get_locVec.*4);
%     n.so('n_goal').vals(3:4)=[10 6]
%     n.so('n_goal').set_vals(goal(1:2)); n.so('n_goal').scaleVals(10);
    fprintf('Starting trial %i; FROM: %i TO: %i \n', trial_i, startingState, goal(1));
    
    for t = dt:dt:endTime 
        
        if atTime(4)
            n.setNode('n_qOn', 1);
            n.so('n_goal').vals(3)=10;
        elseif atTime(14)
            n.setNode('n_qOn', 2);
            n.so('n_goal').vals(4)=10;
            n.so('n_goal').vals(3)=0;
            
            
        end

        
        
        [moved, action, descrip] = e.emwalk(n.so('n_body').vals, MAX_STUCK_TIME, tSinceMove, exploreRate);
        if moved==1
            if action > 0
                n.setNode('n_body', action);
            end             
            n.so('n_env').set_vals(e.get_locVec .* 4);
            n.setNode('n_novInhib', 1);
            tSinceMove = 0;
            
            if TEXT_OUTPUT
                newState = e.curState();
                fprintf('%s: Moving from %i to %i at t = %.2f\n', descrip, lastState, newState, t);
                lastState = newState;
            end
            
        else
            tSinceMove = tSinceMove + dt;      
        end
        n.update(); 
        
        %If at goal, allow a little time for learning
        if e.curState == goal(1) && tSinceMove>5
            disp('goal goal')
            if length(goal)==1
                
                disp('At final goal')
                endTime = t;
                break
                
            else
                t
                 n.setNode('n_qOn', 0);
                n.so('n_goal').vals(goal(1))=0;
                goal(1)=[];
                n.so('n_goal').vals(goal(1))=1;
                
%                 n.so('n_goal').scaleVals(10);
                
                disp('At key goal')
%                                 n.setNode('n_qOn', 1);

                goalTime = t;

                
                
                
            end
        end
    end
    
    if 1
        %%%%%%%%%%%%%%%%%%%%
        %Log Trial Results %
        %%%%%%%%%%%%%%%%%%%%

        batchResults(trial_i, 1) = (e.curState == goal);

        batchResults(trial_i, 2) = endTime; 

        gradWeights = n.so('p_gradient_gradient').weights;
        gradError = sum((gradWeights(:) - correctGradWeights(:)).^2);
        batchResults(trial_i, 3) = gradError;

        adjWeights = n.so('p_state_adjacent').weights;
        adjError = sum((adjWeights(:) - correctAdjWeights(:)).^2);
        batchResults(trial_i, 4) = adjError;

        motorWeights = n.so('p_transOut_motorIn').weights;
        motorError = sum((motorWeights(:) - correctMotorWeights(:)).^2);
        batchResults(trial_i, 5) = motorError;

        totalError = gradError + adjError + motorError;
        batchResults(trial_i, 6) = totalError; 
    end
    
    %%%%%%%%%%%%%%%%%%%%%
    %Plot Trial Results %
    %%%%%%%%%%%%%%%%%%%%%
    close all
    n.plot({'state', 'stateSim', 'adjacent', 'next', 'n_qOn', 'n_qOsc', 'transDes', 'qIn', 'qStore', 'qOut', 'transOut', 'motorIn', 'motorOut', 'n_body'}, 50); 
%     n.plot({'state', 'goal', 'adjacent', 'gradient', 'next'}, 50); %choose next state
%     n.plot({'state', 'n_body', 'prevState1', 'prevMotor', 'prevState2', 'transObs'}, 50); %monitor the past
%     n.plot({'state', 'transObs', 'motorIn', 'transDes', 'motorOut', 'transOut' 'n_body', 'prevMotor'}, 50); %take action
%    
 
    %No idea why, but this plot does not appear but makes all previous
    %plots appear within the loop
    if trial_i < NUM_TRIALS
        figure(99)
    end
    
end

%%%%%%%%%%%%%%
%Export Data %
%%%%%%%%%%%%%%

if 0 
    %activity and weight data
    saveList = {'all'}; %specify layers or projections to export data from
    saveDir = '';

    resp = input(['Save data to directory: ' saveDir '  (y/n)?'], 's');
    if ismember(resp, {'y', 'Y'})
            n.exportPlotData(saveList, [dt,endTime], '', saveDir);

        %batch data
        if 0
           batchSaveDir = '';
           batchSaveName = '';
           csvwrite([batchSaveDir batchSaveName], batchResults) 
        end    
    else
        disp('Data not saved')
    end   
end



%%%%%%%%%%%%%%%
% Batch Plots %
%%%%%%%%%%%%%%%

if 0 
   figure()
   plotData = batchResults(:,2:end);
   numPlots = size(plotData,2);
   
   titles = {'Trial Time', 'Prox Error', 'Adj Error', 'Motor Error', 'Total Weight'};
   
   for plot_i = 1:numPlots
      subplot(numPlots, 1, plot_i)
      hold on
      plot(plotData(:, plot_i), 'LineWidth', 2)
      title(titles{plot_i})
   end
end


%%%%%%%%%%%%%%%
% Trial Plots %
%%%%%%%%%%%%%%%
if 0
    
    %view all possible plotting items with n.names()
    plotItems = {'state', 'adjacent', 'next','transOut', 'motorIn',  'motorOut', 'n_subOsc', 'n_body'};
    n.plot(plotItems, 50)
   
    n.gatePlot('p_gradient_gradient','n_subOsc',20)
    n.gatePlot('p_transOut_motorIn','n_subOsc', [1,20])

    %raw adjacency weights
    figure(11)
    adjWeights = n.so('p_state_adjacent').weights;
    imagesc(adjWeights);
    title('adjacent Weights');
    colorbar
    
    %raw - correct adjacency weights
    figure(12)
    adjWeights = n.so('p_state_adjacent').weights;
    adjWeightError = adjWeights - correctAdjWeights;
    imagesc(adjWeightError, [-1, 1]);
    title('adjacent Weights');
    colorbar
  
    %raw goal gradient weights
    figure(21)
    gradWeights = n.so('p_gradient_gradient').weights;
    imagesc(gradWeights)
    title('gradient Weights');
    colorbar

    %raw - correct goal gradient weights
    figure(22)
    gradWeights = n.so('p_gradient_gradient').weights;
    gradWeightError = gradWeights - correctGradWeights;
    imagesc(gradWeightError, [-1, 1]);
    title('real - correct gradient Weights');
    colorbar

    %raw motor weights
    figure(31)
    motorWeights=n.so('p_transOut_motorIn').weights;
    imagesc(motorWeights)
    title('Action Weights'); 
    colorbar

    %raw - correct motor weights
    figure(32)
    motorWeights = n.so('p_transOut_motorIn').weights;
    motorWeightError = motorWeights - correctMotorWeights;
    imagesc(motorWeightError, [-1, 1]) 
    title('Action Weights');
    colorbar
end

    
    