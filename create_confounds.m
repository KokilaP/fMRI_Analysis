% This file create an FSL-compatile regressor for confound variables (e.g.
% framewise displacement, 6 motion parameters, and acompcor) using the
% regressors computed during the fmriprep pipeline.

%% SET PARAMETERS

bids_dir = '$BIDS_DIR';
fmriprep_dir = '$BIDS_DIR/derivatives/fmriprep';
fsl_dir = fullfile(bids_dir,'derivatives','fsl','confounds');
addpath('$JSONLAB_DIR')


%% CREATE REGRESSORS
% sub_dirs = dir(fullfile(bids_dir,'sub-*'));
%numsubj = numel(sub_dirs);
numsubj = 20;
for s=5:numsubj
    for ses=1:4
        disp(sprintf('Subject: %d & Session: %d',s, ses));
    %     confreg_list = dir(fullfile(fmriprep_dir,sub_dirs(s).name,'func','*confounds_regressors.tsv'));
        path_substring = sprintf('sub-%02d/ses-%d',s,ses);
        confreg_list = dir(fullfile(fmriprep_dir,path_substring,'func','*confounds_regressors.tsv'));
        for r=1:numel(confreg_list) % Loop over runs
            try
                disp(sprintf('     Run: %d',r));
                thisconfreg = tdfread(fullfile(confreg_list(r).folder,confreg_list(r).name));
                foo=strsplit(confreg_list(r).name,'.tsv');
                thisjson = loadjson(fullfile(confreg_list(r).folder,[foo{1} '.json']));
                thisjson_fieldnames = fieldnames(thisjson);
                compcorcovs = find(contains(thisjson_fieldnames,'a_comp_cor'));
                compcorcumvar = nan(length(compcorcovs),1);
                compcormask = cell(length(compcorcovs),1);
                for ii=1:length(compcorcovs)
                    compcorcumvar(ii) = thisjson.(['a_comp_cor_' sprintf('%02d',ii-1)]).CumulativeVarianceExplained;
                    compcormask{ii} = thisjson.(['a_comp_cor_' sprintf('%02d',ii-1)]).Mask;
                end
                compcor_COMBcomponents = find(contains(compcormask,'combined'));
                compcor_WMcomponents = find(contains(compcormask,'WM'));
                compcor_CSFcomponents = find(contains(compcormask,'CSF'));

                % Extract framewise displacement covariate
                fd_confound = nan(size(thisconfreg.framewise_displacement,1),1);
                for ii=1:size(thisconfreg.framewise_displacement,1)
                    fd_confound(ii) = str2double(thisconfreg.framewise_displacement(ii,:));
                end
                fd_confound = fd_confound-nanmean(fd_confound);
                fd_confound(isnan(fd_confound)) = 0;

                % Extract motion covariates
                motion_confounds = [thisconfreg.trans_x thisconfreg.trans_y thisconfreg.trans_z thisconfreg.rot_x thisconfreg.rot_y thisconfreg.rot_z];
                motion_confounds = motion_confounds - repmat(nanmean(motion_confounds),size(motion_confounds,1),1);

                % Use top 5 components (combined across WM and CSF)
                acompcor_combined5 = [thisconfreg.a_comp_cor_00 thisconfreg.a_comp_cor_01 thisconfreg.a_comp_cor_02 thisconfreg.a_comp_cor_03 thisconfreg.a_comp_cor_04];
                % Use top 5 WM components
                acompcor_WM1 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_WMcomponents(1)-1)]);
                acompcor_WM2 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_WMcomponents(2)-1)]);
                acompcor_WM3 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_WMcomponents(3)-1)]);
                acompcor_WM4 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_WMcomponents(4)-1)]);
                acompcor_WM5 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_WMcomponents(5)-1)]);
                % Use top 5 CSF components
                acompcor_CSF1 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_CSFcomponents(1)-1)]);
                acompcor_CSF2 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_CSFcomponents(2)-1)]);
                acompcor_CSF3 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_CSFcomponents(3)-1)]);
                acompcor_CSF4 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_CSFcomponents(4)-1)]);
                acompcor_CSF5 = thisconfreg.(['a_comp_cor_' sprintf('%02d',compcor_CSFcomponents(5)-1)]);
                % Combined acompcor components
                acompcor_CSF5WM5 = [acompcor_WM1 acompcor_WM2 acompcor_WM3 acompcor_WM4 acompcor_WM5 acompcor_CSF1 acompcor_CSF2 acompcor_CSF3 acompcor_CSF4 acompcor_CSF5];
                acompcor_CSF5WM5 = acompcor_CSF5WM5 - repmat(nanmean(acompcor_CSF5WM5),size(acompcor_CSF5WM5,1),1);

                % Create a combined confound variable
                all_confounds1 = [fd_confound motion_confounds];
                all_confounds2 = [fd_confound motion_confounds acompcor_combined5];
                all_confounds3 = [fd_confound motion_confounds acompcor_CSF5WM5];

                confreg_list_parts = strsplit(confreg_list(r).name,'_');
                destdir = fullfile(fsl_dir,confreg_list_parts{1},confreg_list_parts{2},'_regressors');
                if exist(destdir,'dir')==0
                    mkdir(destdir);
                end
                destfilename1 = [confreg_list_parts{1} '_' confreg_list_parts{2} '_' confreg_list_parts{3} '_confounds_fd_motion.txt'];
                destfilename2 = [confreg_list_parts{1} '_' confreg_list_parts{2} '_' confreg_list_parts{3} '_confounds_fd_motion_acompcorcombined5.txt'];
                destfilename3 = [confreg_list_parts{1} '_' confreg_list_parts{2} '_' confreg_list_parts{3} '_confounds_fd_motion_acompcorCSF5WM5.txt'];

                % Write to file
                dlmwrite(fullfile(destdir,destfilename1),all_confounds1, 'delimiter', '\t', 'precision', 9);
                dlmwrite(fullfile(destdir,destfilename2),all_confounds2, 'delimiter', '\t', 'precision', 9);
                dlmwrite(fullfile(destdir,destfilename3),all_confounds3, 'delimiter', '\t', 'precision', 9);
            end
        end
    end
end
