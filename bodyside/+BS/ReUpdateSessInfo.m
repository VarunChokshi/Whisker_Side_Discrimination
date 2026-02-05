function ReUpdateSessInfo(dataFileTb)%% Re-update se with sessInfo
    parfor i =1:height(dataFileTb)
        se1 = load(dataFileTb.sePath{i});
        se = se1.se;
        if ~isempty(dataFileTb.sessInfoPaths{i})
            seshInfoTb = readtable(dataFileTb.sessInfoPaths{i}); 
            seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
                'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
            
            ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(dataFileTb.sessionDatetime(i))) & subId == cell2mat(seshInfoTb.subId);
            seshInfoTb = seshInfoTb(ind,:);     
            seshInfo = seshInfoTb; 
            se.userData.sessionInfo = seshInfo;
        end
          % Save SE
        disp('Saving SE to disk');    
        BS.saveSE(dataFileTb.sePath{i},se);
          
       
        fprintf('\n');
        
    end
end
