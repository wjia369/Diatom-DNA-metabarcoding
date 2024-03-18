# Script to run OBITools 3 with demultiplexed reads
# Written by Weihan Jia and Ugur Cabuck
# Email: weihan.jia@awi.de

#!/bin/bash
#SBATCH --account=envi.envi
#SBATCH -t48:00:00
#SBATCH --qos=48h 
#SBATCH -p smp 
#SBATCH -c 32
#SBATCH --job-name=diatom
#SBATCH --output=%x_%j.out
#SBATCH --mail-user=weihan.jia@awi.de
#SBATCH --mail-type=ALL
#SBATCH --array=1-61%1

ulimit -s unlimited

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export SRUN_CPUS_PER_TASK=$SLURM_CPUS_PER_TASK

module load obitools/3.0.1b20


# prepare the data and working directories
DMS_OUT="/albedo/work/user/wjia/diatom/results"
DATAPATH="/albedo/work/user/wjia/diatom/data/ngsfiltered"
SEQDATA=".fastq"
ID=diatom_

WORK=${PWD}
cd ${DATAPATH}
INPUT1=$(ls *${INPUT1} | sed -n ${SLURM_ARRAY_TASK_ID}p)
OUT_FILE=${INPUT1%${SEQDATA}}
cd ${WORK}

DMS="/tmp/diatom_${OUT_FILE}"

# reference database
RBCL=/albedo/work/projects/p_biodiv_dbs/obitools/embl_db22-10-06_rbcl.obidms

# copy data files to tmp (on calculating node)
rsync -ur $DATAPATH/${INPUT1} /tmp/
rsync -ur $RBCL /tmp/

# set tmp variables
DATA=/tmp/${INPUT1}
RBCL_tmp=/tmp/embl_db22-10-06_rbcl.obidms

# import data
srun obi import --fastq-input $DATA $DMS/${ID}${OUT_FILE}reads

# dereplicate sequences into unique sequences
srun obi uniq --no-progress-bar $DMS/${ID}${OUT_FILE}reads $DMS/${ID}${OUT_FILE}dereplicated_sequences

# denoise data, only keep COUNT and merged_sample tags
srun obi annotate -k COUNT -k MERGED_sample $DMS/${ID}${OUT_FILE}dereplicated_sequences $DMS/${ID}${OUT_FILE}cleaned_metadata_sequences

# filtering
srun obi grep -p "len(sequence)>=1 and sequence['COUNT']>=1" $DMS/${ID}${OUT_FILE}cleaned_metadata_sequences $DMS/${ID}${OUT_FILE}cleaned_0_metadata_sequences

# denoise data, clean from pcr/sequencing errors
srun obi clean --no-progress-bar -r 0.05 -H $DMS/${ID}${OUT_FILE}cleaned_0_metadata_sequences $DMS/${ID}${OUT_FILE}cleaned_sequences

# clean DMS
srun obi clean_dms $DMS

# assign to the 'RBCL' database
srun obi clean_dms $RBCL_tmp
srun obi ecotag --taxonomy $RBCL_tmp/TAXONOMY/ncbi_tax_23-02-16 -R $RBCL_tmp/VIEWS/rbcl_embl_db22-10-06_db.obiview $DMS/${ID}${OUT_FILE}cleaned_sequences $DMS/${ID}${OUT_FILE}rbcl_assigned_sequences

# annonate lineage information
srun obi annotate --with-taxon-at-rank family --with-taxon-at-rank genus --with-taxon-at-rank species --taxonomy $RBCL_tmp/TAXONOMY/ncbi_tax_23-02-16 $DMS/${ID}${OUT_FILE}rbcl_assigned_sequences $DMS/${ID}${OUT_FILE}rbcl_annotated_sequences

# export the results as a csv file
srun obi export --tab-output $DMS/${ID}${OUT_FILE}rbcl_annotated_sequences > ${DMS}.obidms/${ID}${OUT_FILE}_rbcl_anno.csv

# copy output csv files from calculating node to work folder
srun mv ${DMS}.obidms/${ID}${OUT_FILE}_rbcl_anno.csv $DMS_OUT
