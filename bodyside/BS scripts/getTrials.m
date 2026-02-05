%Plot all Right Correct trials
function seIn = getTrials(se, input)
    seIn = se.Duplicate();    
    trialsToKeep = seIn.GetColumn('behavValue', input);
    keepTrials = find(~sum(trialsToKeep, 2));
    seIn.RemoveEpochs(keepTrials);
end
