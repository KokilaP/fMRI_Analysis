#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH -o $HOME/log_fmriprep.out

sub=${SLURM_ARRAY_TASK_ID}
export SCRATCH_DIR="${SPHERE_DIR}/scratch_fmriprep_${sub}"
mkdir ${SCRATCH_DIR}

# Compose the command line
if [ "$USETEMPLATEFLOW" = true ] ; then
    # Prepare some writeable bind-mount points.
    TEMPLATEFLOW_HOST_HOME=${MAIN_DIR}/.cache/templateflow
    FMRIPREP_HOST_CACHE=${MAIN_DIR}/.cache/fmriprep
    mkdir -p ${TEMPLATEFLOW_HOST_HOME}
    mkdir -p ${FMRIPREP_HOST_CACHE}
    SINGULARITY_CMD="singularity run --cleanenv \
        --bind ${TEMPLATEFLOW_HOST_HOME:-${MAIN_DIR}/.cache/templateflow}:/templateflow \
        --bind ${MAIN_DIR}:/home \
        --bind $BIDS_DIR:/data \
        --bind $SCRATCH_DIR:/work \
        $FMRIPREPIMAGE"
    #PS; ${parameter:-word} -- If parameter is unset or null, the expansion of word is substituted. Otherwise, the value of parameter is substituted.
else
    SINGULARITY_CMD="singularity run --cleanenv \
        --bind ${MAIN_DIR}:/home \
        --bind $BIDS_DIR:/data \
        --bind $SCRATCH_DIR:/work \
        $FMRIPREPIMAGE"
fi

# Parse the participants.tsv file and extract one subject ID from the line corresponding to this SLURM task.
subject=$( sed -n -E "$((${SLURM_ARRAY_TASK_ID} + 1))s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv )

# Remove IsRunning files from FreeSurfer
if [ -d "${BIDS_DIR}/derivatives/freesurfer-6.0.1/sub-$subject/" ] ; then
    find ${BIDS_DIR}/derivatives/freesurfer-6.0.1/sub-$subject/ -name "*IsRunning*" -type f -delete
fi

# Compose the command line
if [ "$RUNFSRECONALL" = true ] ; then
    cmd="${SINGULARITY_CMD} \
    --participant-label $subject \
    --force-syn \
    --fs-license-file ${FS_LICENSE_DIR}/license.txt \
    --bold2t1w-dof 6 --nthreads 8 --omp-nthreads 7 \
    --output-spaces fsaverage6 fsnative anat func MNI152NLin2009cAsym:res-2 MNI152NLin6Asym:res-2 \
    --use-aroma \
    --work-dir /work \
    --clean-workdir \
    --write-graph --notrack -vv \
    /data /data/derivatives participant"
else
    cmd="${SINGULARITY_CMD} \
    --participant-label $subject \
    --fs-license-file /data/derivatives/license.txt \
    --fs-no-reconall \
    --bold2t1w-dof 6 --nthreads 8 --omp-nthreads 8 \
    --output-spaces anat func MNI152NLin2009cAsym:res-2 MNI152NLin6Asym:res-2 \
    --use-aroma \
    --work-dir /work \
    --write-graph --notrack -vv \
    /data /data/derivatives participant"
fi

# Setup done, run the command
echo Running task ${SLURM_ARRAY_TASK_ID}
echo Commandline: $cmd
eval $cmd
exitcode=$?

# Output results to a table
echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    $exitcode" \
      >> ${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
echo Finished tasks ${SLURM_ARRAY_TASK_ID} with exit code $exitcode
exit $exitcode