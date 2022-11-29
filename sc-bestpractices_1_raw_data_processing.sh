conda create -n af_xmpl
conda activate af_xmpl
conda install -c conda-forge -c bioconda python=3.9 salmon alevin-fry pyroe

# Create a working dir and go to the working directory
## The && operator helps execute two commands using a single line of code.
mkdir af_xmpl_run && cd af_xmpl_run

# Download the example dataset and CB permit list and decompress them
## The pipe operator (|) passes the output of the wget command to the tar command.
## The dash operator (-) after `tar xzf` captures the output of the first command.
## - example dataset
wget -qO- https://umd.box.com/shared/static/lx2xownlrhz3us8496tyu9c4dgade814.gz | tar xzf - --strip-components=1 -C .

# Download CB permit list
## the right chevron (>) redirects the STDOUT to a file
wget -qO- https://raw.githubusercontent.com/10XGenomics/cellranger/master/lib/python/cellranger/barcodes/3M-february-2018.txt.gz | gunzip - > 3M-february-2018.txt

# make splici reference
## Usage: pyroe make-splici genome_file gtf_file read_length out_dir
## The read_lengh is the number of sequencing cycles performed by the sequencer. Ask your technician if you are not sure about it.
## Publicly available datasets usually have the read length in the description.
pyroe make-splici \
toy_human_ref/fasta/genome.fa \
toy_human_ref/genes/genes.gtf \
90 \
splici_ref

# Index the reference
## Usage: salmon index -t extend_txome.fa -i idx_out_dir -p num_threads
## The $() expression runs the command inside and put the output in place.
## Please make sure that there is only one file ending with ".fa" in the `splici_ref` folder.
salmon index \
-t $(ls splici_ref/*\.fa) \
-i splici_idx \
-p 8

# Collect FASTQ files
## The reads1 and reads2 variable are defined by finding the filenames with the pattern "_R1_" and "_R2_" from the toy_read_fastq directory.
## The filenames are sorted to make sure that the order of files in reads1 and reads2 are the same, which is required by salmon.
fastq_dir="toy_read_fastq"
reads1_pat="_R1_"
reads2_pat="_R2_"
reads1="$(find -L $fastq_dir -name "*$reads1_pat*" -type f | xargs | sort | awk '{print $0}')"
reads2="$(find -L $fastq_dir -name "*$reads2_pat*" -type f | xargs | sort | awk '{print $0}')"

# Mapping
## Usage: salmon alevin -i idx_out_dir -l library_type -1 reads1_files -2 reads2_files -p num_threads -o map_out_dir
## The variable reads1 and reads2 defined above are passed in using ${}.
salmon alevin \
-i splici_idx \
-l ISR \
-1 ${reads1} \
-2 ${reads2} \
-p 8 \
-o alevin_map \
--chromiumV3 \
--sketch

# Cell barcode correction
## Usage: alevin-fry generate-permit-list -u CB_permit_list -d expected_orientation -o gpl_out_dir
## Here, the reads that map to the reverse complement strand of transcripts are filtered out by specifying `-d fw`.
alevin-fry generate-permit-list \
-u 3M-february-2018.txt \
-d fw \
-i alevin_map \
-o gpl

# Filter mapping information
## Usage: alevin-fry collate -i gpl_out_dir -r alevin_map_dir -t num_threads
alevin-fry collate \
-i gpl \
-r alevin_map \
-t 8

# UMI resolution + quantification
## Usage: alevin-fry quant -r resolution -m txp_to_gene_mapping -i gpl_out_dir -o quant_out_dir -t num_threads
## The file ends with `3col.tsv` in the splici_ref folder will be passed to the -m argument.
## Please make sure that there is only one such file in the `splici_ref` folder.
alevin-fry quant -r cr-like \
-m $(ls splici_ref/*3col.tsv) \
-i gpl \
-o quant \
-t 8

# Each line in `quants_mat.mtx` represents
# a non-zero entry in the format row column entry
tail -3 quant/alevin/quants_mat.mtx
138 59 1
139 10 1
139 38 1

# Each line in `quants_mat_cols.txt` is a splice status
# of a gene in the format (gene name)-(splice status)
tail -3 quant/alevin/quants_mat_cols.txt
ENSG00000134352-A
ENSG00000120705-A
ENSG00000198961-A

# Each line in `quants_mat_rows.txt` is a corrected
# (and, potentially, filtered) cell barcode
tail -3 quant/alevin/quants_mat_rows.txt
TTCGATTTCCGCTTAC
TGCTCGTGTTCGAAGG
ACTGTGAAGAAATTGC