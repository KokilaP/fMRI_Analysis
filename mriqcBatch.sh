#!/bin/bash
#SBATCH --job-name=mriqc
#SBATCH -o $HOME/log_mriqc.out

sub=${SLURM_ARRAY_TASK_ID}
export SCRATCH_DIR="${SPHERE_DIR}/scratch_mriqc_${sub}"
mkdir ${SCRATCH_DIR}

SINGULARITY_CMD="singularity run --cleanenv 
	--bind $BIDS_DIR:/data
	--bind $SCRATCH_DIR:/work \
	${MRIQCIMAGE}"

for subject in 02 03 04 05 06 07 08 09 10
do
    echo Running command for subject $subject
    cmd="${SINGULARITY_CMD} \
    --participant-label $subject \
    --no-sub \
    --modalities T1w bold \
    --nprocs 1 \
    -v \
    --verbose-reports \
    --correct-slice-timing \
    --work-dir /work \
    /data /data/derivatives/mriqc participant"

    echo Commandline: $cmd
    eval $cmd
    exitcode=$?
    echo Finished subject $subject with exit code $exitcode
done
echo Finished tasks with exit code $exitcode
exit $exitcode
