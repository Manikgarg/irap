# =========================================================
# Copyright 2012-2017,  Nuno A. Fonseca (nuno dot fonseca at gmail dot com)
#
# This file is part of iRAP.
#
# This is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with iRAP.  If not, see <http://www.gnu.org/licenses/>.
#
#
# =============================================================

# Main code

###############################################################
# disable deletion of temporary files
.SECONDARY: 
.ONESHELL:

SHELL=bash
################################################################################
# Auxiliary functions
################################################################################

# Information messages
define p_info=
$(info $(shell date "+%H:%M:%S %d/%m/%Y * ") $(1))
endef

# Error messages
define p_error=
$(info $(shell date "+%H:%M:%S %d/%m/%Y") * ERROR: $(1)) && $(error Fatal error: $(1))
endef

# check if the parameter has a value - prints an error if not
ifdef verbose
define check_ok=
$(if $($(1)),$(call p_info, *	$(1)=$($(1))),$(p_error Missing $(1)))
endef
else
define check_ok=
$(if $($(1)),,$(p_error Missing $(1)))
endef
endif

# complain if a file does not exist and exit
file_exists=$(if  $(realpath $(1)),,$(call p_error,$(1) not found))
file_exists_ce=$(if  $(realpath $(1)),,$(call p_error,$(1) - $(2)))

#  check if a variable  $(1) is defined - return the variable name if it is defined or empty otherwise
is_defined=$(if $(subst undefined,,$(origin $(1))),$(1),)


###################################################################
# Variables
ifdef def_lib_dir
override def_lib_dir:=$(patsubst %/,%,$(def_lib_dir))/
endif
#

ifneq ($(origin raw_data_dir),undefined)
def_lib_dir:=
endif

#raw_data_dir?=
def_lib_dir?=

$(info ---------$(def_lib_dir))
# ensure that the dir name starts and ends with a /
check_libdir_ok=$(if $(call is_defined,$(1)_dir),$(patsubst %/,%,$($(1)_dir))/,$(def_lib_dir))

# *****************
# Stranded data
# return y if the strand info was provided
lib_strand_info=$(if $(call is_defined,$(1)_strand),y,)

# strand value
VALID_STRAND_OPTIONS=first second both
# return non empty if option is invalid
strand_value_ok=$(if $(filter $($(1)),$(VALID_STRAND_OPTIONS)),invalid option $($(1)) for $(1),)

# check if stranded information is ok
check_libstrand_ok=$(if $(call is_defined,$(1)_strand),$(if $(call strand_value_ok,$(1)_strand),$(call set_has_stranded_data,$(1)) $($(1)_strand),$(call p_error,Invalid strand option for lib $(1) - $($(1)_strand))))

# validate the read group id info
check_rgid_ok=$(call get_rgid,$(1))
get_rgid=$(if $(call is_defined,$(1)_rgid),$($(1)_rgid),)

# sam header
# add @rg if not defined
check_sheader_ok=$(if $(call is_defined,$(1)_shl),$($(1)_shl),$(if $($(1)_rgid),'@RG	ID:$($(1)_rgid)',))

has_stranded_data=no
set_has_stranded_data=$(if $(filter both,$($(1)_strand)),,$(eval has_stranded_data=yes))
##########################
# barcode values - lib, bc
check_bc_value_ok=$(if $(call is_defined,$(1)_$(2)),$($(1)_$(2)),$(def_$(bc)))

# the following parameters may be defined once - and are applied as default values
# for all libraries/assays - or defined per assay
def_umi_read?=undef
def_umi_offset?=0
def_umi_size?=0
def_cell_read?=undef
def_cell_offset?=0
def_cell_size?=0
def_sample_read?=undef
def_sample_offset?=0
def_sample_size?=0
def_read1_offset?=0
def_read1_size?=-1
def_read2_offset?=0
def_read2_size?=-1
def_index1?=undef
def_index2?=undef
def_known_umi_file?=

barcode_min_qual?=10
# ****************
# Paths
# get the path for a filtered fastq file
lib2filt_folder=$(name)/data/qc/$($(1)_dir)
# get the path for a bam file
lib2bam_folder=$(name)/$(mapper)/$($(1)_dir)
#
lib2snp_folder=$(name)/$(mapper)/$($(1)_dir)
#
lib2quant_folder=$(name)/$(mapper)/$(quant_method)/$($(1)_dir)
#
lib2fusion_folder=$(name)/$(mapper)/$(fusion_method)/$($(1)_dir)

# check if a parameter is defined
check_param_ok=$(if $(call is_defined,$(strip $(1))),$(info *	$(1)=$($(1))),$(error * Missing -$(1)-))

# check  contrast name
# 1 - param 2-param_name
check_name=$(if $(shell echo $(1)|sed "s/[0-9]*//g"),,$(error * Invalid $(2) $(1)))


# the library name should be different from the prefix of the fastq files
# ex. of an invalid library name: lib1=lib1.fastq
# 1=libname
check_se_libname_ok=$(if $(subst $(1).fastq,,$($(1))),, $(error * Invalid libname $(1)))
check_pe_libname_ok=$(if $(strip $(subst $(1)_2.fastq,,$(subst $(1)_1.fastq,,$($(1))))), ,$(error * Invalid libname $(1)))

# 1 - lib
# 2 - bam
define convert_bam2sefastq=
$(call file_exists,$(2))
$(eval override $(1):=$(notdir $(basename $(2))).fastq)
endef
define convert_bam2pefastq=
$(call file_exists,$(2))
$(eval override $(1):=$(notdir $(basename $(2)))_1.fastq $(notdir $(basename $(2)))_2.fastq)
endef


# which program to use to merge the tsv files
# 1 = quant_method
# TODO: reduce memory footprint of irap_merge_tsv_NA.sh 
define merge_tsv=
$(if $(findstring cufflinks,$(1)),irap_merge_tsv_NA.sh,irap_merge_tsv.sh)
endef

################################################################################
# Variables
################################################################################

## default is bulk (blk)
rnaseq_type?=blk

## single_cell_protocol=none 
sc_protocol?=none

ifndef debug	
 debug=1
p_debug=
else
p_debug=$(info DEBUG:$(1))
endif

ifndef pe
 pe=
else
override pe:=$(sort $(pe))
endif

ifndef se
 se=
else
override se:=$(sort $(se))
endif


#************************
#Version and license info
pname=IRAP
version=0.8.5d3
contact=Developed by Nuno Fonseca (authorname (at) acm.org)
license=This pipeline is distributed  under the terms of the GNU General Public License 3


################################################################################
# Default values
################################################################################
def_gse_tool=none

# max. memory (in MB)
def_max_mem=6000

#Contamination file
def_cont_index=$(data_dir)/contamination/e_coli

#Default number of threads to run on a computer farm
def_max_threads=1

#Minimal base quality accepted
def_min_read_quality=10

# Trim poly-A/T? y|n
def_trim_poly_at=n

# minimum poly-at length
# by default, if a read has at least 10 consecutive A or T in the edges then it will be trimmed. This option is only used if trim_poly_at is set to y
def_trim_poly_at_len=10

#Trim all reads to the minimum read size after quality trimming - y/n
def_trim_reads=y

# none is being kept for backwards compatibility
# Quality filtering - on/report/off/none (alias: qc)
def_qual_filtering=on

# Mapper to use in QC contamination check 
def_cont_mapper=bowtie

#Software for mapping (reads -> genome/transcriptome)
def_mapper=tophat2
def_mapper_splicing=yes

#Software for differential expression
def_de_method=none

#Is the experiment designed to compare the results of different mappers? yes|no => undef conditions|contrasts
def_mapper_comparison=no

# default method to count reads mapped to features (genes, exons, ...)
def_quant_method=htseq2

# default method to normalize the expression values
def_quant_norm_method=none

# default tool to compute the normalized expression values
def_quant_norm_tool=none

# produce quantification per exon? default is gene level or transcript level depending on the method used
def_exon_quant=n
def_transcript_quant=n

# maximum number of hits reported by the mapper
def_max_hits=10

# fix NH flags in bam files
def_fix_NH=y

# use only a subset of the genes in the DE analysis (y|n)
def_de_annot_genes_only=n

# Htseq - produce a sam file with annotations?y/n
htseq_sam_output_def=n

# Dominant transcript fold-change - no (n) to disables it
# only used if transcript quantification is y
dt_fc=2

# DE
def_de_pvalue_cutoff=0.05
def_de_num_genes_per_table=300

#def_annot_tsv=auto
def_annot_tsv=off

CSS_FILE?=irap.css

###########
## Internal 
isl_mode?=n

################################################################################
# START!
$(info *****************************************************)
$(info * $(pname) $(version))
$(info * $(contact))
$(info * $(license))
$(info *)

$(info * Initializing...)


###############################################
# Load configuration (mandatory)
ifdef conf
 $(call file_exists,$(conf))
 $(info * Trying to load configuration file $(conf)...)
 include $(conf)
 $(info * Configuration loaded.)
else
 $(call p_error,Configuration file missing)
endif

# load library specific information
ifdef lib.info
lib_info=$(lib.info)
endif

ifdef lib_info
 $(call file_exists,$(lib_info))
 $(info * Trying to load information about the libraries - file $(lib_info)...)
 include $(lib_info)
 $(info * Information about the libraries loaded.)
endif


###############################################
# Load some definitions
include $(irap_path)/../aux/mk/irap_defs.mk

###############################################################
# Check and validate the parameters values
# fastq files -> pair-end, single-end or both

$(info * )
$(info * Required Parameters:)

#***********************
# Name of the experiment
ifndef name
 $(call p_error, missing argument name!)
else
 $(info *	name=$(name))
endif



#************************
# data_dir Data directory (directory where the data is expected to be)
# Directory organization
# data_dir/reference/species/(fasta+(cdna+gtf))
# default: data_dir/raw_data/$(raw_folder)/

# check if data dir exists and structure is OK
# TODO
ifndef data_dir
 $(call p_error,missing argument data_dir)
endif


$(info *	data_dir=$(data_dir))
$(call file_exists,$(data_dir))


#********
# Species
ifndef species
 $(call p_error,missing argument species)
else
 $(info *	species=$(species))
endif

#****************
# raw data folder
ifndef raw_folder
 raw_folder=$(species)
endif

#***************
# raw_data_dir - folder where the raw data (fastq/bam) may be found
# 
ifdef raw_data_dir
ifneq ($(raw_data_dir)-,-)
# not empty
override raw_data_dir:=$(raw_data_dir)/
endif
endif
# always add a end /
raw_data_dir?=$(data_dir)/raw_data/$(raw_folder)/
$(info *	raw_data_dir=$(raw_data_dir))

#**********************
# Reference genome file
ifndef reference
 $(call p_error,missing argument reference)
endif

# 
reference_dir:=$(abspath $(data_dir)/reference/$(species))
reference_abspath:=$(abspath $(reference_dir)/$(subst .gz,,$(reference)))
reference_prefix:=$(reference_abspath)
reference_basename=$(notdir $(reference_abspath))
# remove .gz if the file is gziped...the creation of the uncompress file is automatic

$(info *	reference=$(reference))
$(call file_exists,$(reference_dir)/$(reference))
#********* 
# GTF file
ifndef gtf_file
 gtf_file?=$(subst .fa,.gtf,$(reference))
endif

# remove .gz if the file is gziped...the creation of the uncompress file is automatic
gtf_file_dir:=$(abspath $(data_dir)/reference/$(species))
gtf_file_abspath:=$(abspath $(gtf_file_dir)/$(subst .gz,,$(gtf_file)))
gtf_file_basename:=$(notdir $(gtf_file_abspath))

$(info *       gtf_file  = $(gtf_file))
$(call file_exists,$(gtf_file_dir)/$(gtf_file))

# irap's gtf file
# lgtf_file_dir:=

# ************
# spikein data
ifdef spikein_fasta
ifeq ($(spikein_fasta),ERCC)
override spikein_fasta:=$(data_dir)/ercc.fasta.gz
spikein_fasta_abspath:=$(abspath $(spikein_fasta))
else
spikein_fasta_abspath:=$(abspath $(spikein_fasta))
endif

endif

ifdef spikein_fasta
spikein_data=y
$(info *	spikein_data=y)
#spikein_fasta_abspath:=$(raw_data_dir)/$(spikein_fasta)
$(call file_exists,$(spikein_fasta_abspath))
# remove .gz
override spikein_fasta_abspath:=$(subst .gz,,$(spikein_fasta_abspath))
# gtf and fasta files
# new reference file cannot be shared across experiments
reference_dir:=$(name)/data
user_reference_abspath:=$(reference_abspath)
# newref: ref_prefix.spikein_prefix.fasta
spikein_fasta_prefix=$(patsubst %.fa,,$(patsubst %.fa,%,$(patsubst %.gz,%,$(notdir $(spikein_fasta)))))
new_spike_ref_prefix:=$(dir $(reference_abspath))/$(patsubst %.fasta,%.$(spikein_fasta_prefix),$(patsubst %.fa,%.fasta,$(subst .gz,,$(reference))))
override reference_abspath:=$(new_spike_ref_prefix).fa
reference_prefix=$(reference_abspath)

reference_basename=$(notdir $(reference_abspath))
#
gtf_file_dir:=$(name)/data
user_gtf_abspath:=$(gtf_file_abspath)
gtf_file_abspath:=$(name)/data/$(subst .fasta,,$(spikein_fasta_prefix)).$(subst .gz,,$(notdir $(user_gtf_abspath)))
spikein_gtf_file:=$(patsubst %.fasta,%.gtf,$(spikein_fasta_abspath))
override gtf_file:=$(notdir $(gtf_file_abspath))

## concentration (TSV file)
ifndef spikein_concentration
spikein_concentration=
$(info * Warning:  spikein concentration not provided)
endif

#
$(info * Currently spikein data is not explored when performing differential expression analysis)
endif


# ****************
# single cell
ifndef single_cell
single_cell=n
endif


# ****************
# file with the junctions (as used by tophat)
# offset=0
# includes 1 base of the exons
juncs_file_abspath:=$(subst .gz,,$(gtf_file_abspath)).juncs
juncs_file:=$(notdir $(juncs_file_abspath))



ifndef gff3_file
# GFF3 file obtained from the gtf file
gff3_file_abspath:=$(name)/data/$(patsubst %.gtf,%.gff3,$(subst .gz,,$(gtf_file)))
else
gff3_file_abspath:=$(subst .gz,,$(gff3_file))
endif

gff3_file:=$(notdir $(gff3_file_abspath))
$(info *       gff3_file  = $(gff3_file_abspath))


# mapping (exon/transcript to gene) file obtained from the gtf file
feat_mapping_file?=$(subst .gz,,$(subst .gtf,.mapping.Rdata,$(gtf_file_abspath)))

#**********
# cDNA file
ifndef cdna_file
 cdna_file?=$(subst .dna.fa,.cdna.all.fa,$(reference))
 ifeq ($(cdna_file),$(reference))
   cdna_file=$(subst .fa,.cdna.all.fa,$(reference))
 endif
endif
cdna_dir:=$(abspath $(data_dir)/reference/$(species))
cdna_file_abspath=$(abspath $(cdna_dir)/$(cdna_file))
cdna_file_fasta_abspath=$(abspath $(cdna_dir)/$(subst .gz,,$(cdna_file)))

#$(info *       CDNA = $(cdna_file))
# TODO: only report an error if the file is really needed
#$(call file_exists,$(cdna_dir)/$(cdna_file))


#trans_file?=$(abspath $(data_dir)/reference/$(species)/$(shell echo $(reference)|sed "s/.dna.fa/.trans.fa/" | sed "s/.gz//"))
trans_file?=$(cdna_file_abspath)
$(info *       Transcripts = $(trans_file))
#$(call file_exists,$(trans_file))


refgeneclass_file=$(subst .gz,,$(gtf_file_abspath)).gene_class.txt
refgeneannot_file=$(subst .gtf,,$(subst .gz,,$(gtf_file_abspath))).gene_annot.tsv

#************
# FASTQ files
# SE reads
all_se_files=""
all_pe_files=""

# no need to check the se and pe parameters if
# the target is stage0 only
TARGETS=
ifdef MAKECMDGOALS
TARGETS=$(MAKECMDGOALS)
endif

# skip validation of SE or PE
ifeq ($(TARGETS),stage0)
skip_lib_validation=no
endif
ifeq ($(TARGETS),stage0_fix)
skip_lib_validation=no
endif


#
ifdef skip_lib_validation
$(info "Skipping validation of se and pe")
override se:=
override pe:=
else
ifdef se
 $(info *	se=$(se))
 all_se_files=$(foreach l,$(se),$($(l)))
 #$(foreach l,$(se),$(info $(l)=$($(l)))) 
 # check if fastq file is in a different directory
 $(foreach l,$(se),$(eval $(l)_dir=$(call check_libdir_ok,$(l))))
 $(foreach l,$(se),$(eval $(l)_strand=$(call check_libstrand_ok,$(l)))) 
# read group id
 $(foreach l,$(se),$(eval $(l)_rgid=$(call check_rgid_ok,$(l)))) 
# sam header (may/should include @RG)
 $(foreach l,$(se),$(eval $(l)_shl=$(call check_sheader_ok,$(l)))) 
 #$(foreach l,$(se),$(info $(l)_dir=$($(l)_dir)))
 #$(foreach l,$(se),$(info $(l)_dir=$($(l)_dir)))
 #$(foreach l,$(se),$(info $(l)_dir=$(call check_libdir_ok,$(l))))
 $(foreach l,$(se),$(call check_se_libname_ok,$(l)))
 $(foreach l,$(se),$(call check_param_ok,$(l)_rs))
 $(foreach l,$(se),$(call check_param_ok,$(l)_qual))
 $(foreach l,$(se),$(foreach bc,known_umi_file index1 index2 umi_read umi_offset umi_size cell_read cell_offset cell_size sample_read sample_offset sample_size read1_offset read2_offset read1_size read2_size,$(eval $(l)_$(bc)=$(call check_bc_value_ok,$(l),$(bc)))))
 ifile_given=1
endif

# PE files (libraries)
# lib=A B C
# 
# A=""
ifdef pe
 all_pe_files=$(foreach l,$(pe),$($(l)))
 map=$(foreach a,$(2),$(abspath $(call $(1),$(a))))
 deref=$($1)
 fastq_files?=$(call map, deref, $(pe))
 $(info *	pe=$(pe))
 # $(info * debug * fastq_files=$(fastq_files))
 # check the definition of 
 #  insert size
 #  sd
 #  read size
 #  read group id
 #  shl (sam header lines)
 # spike_fasta - single lib only
 # spike_concentration - single lib only
 # for each lib
 rs_list=
 set_rs_list=$(eval rs_list+= $($(1)))
 $(foreach l,$(pe),$(call check_pe_libname_ok,$(l)))
 $(foreach l,$(pe),$(eval $(l)_dir=$(call check_libdir_ok,$(l))))
 $(foreach l,$(pe),$(eval $(l)_strand=$(call check_libstrand_ok,$(l))))
# read group id
 $(foreach l,$(pe),$(eval $(l)_rgid=$(call check_rgid_ok,$(l)))) 
# sam header lines (may/should include @RG)
 $(foreach l,$(pe),$(eval $(l)_shl=$(call check_sheader_ok,$(l)))) 
 #$(foreach l,$(pe),$(info $(l)_dir=$($(l)_dir)))
 $(foreach l,$(pe),$(call check_param_ok,$(l)_sd))
 $(foreach l,$(pe),$(call check_param_ok,$(l)_ins))
 $(foreach l,$(pe),$(call check_param_ok,$(l)_rs))
 $(foreach l,$(pe),$(call check_param_ok,$(l)_qual))
 $(foreach l,$(pe),$(call set_rs_list,$(l)_rs))
 $(foreach l,$(pe),$(foreach bc,umi_read umi_offset umi_size cell_read cell_offset cell_size sample_read sample_offset sample_size read1_offset read2_offset read1_size read2_size,$(eval $(l)_$(bc)=$(call check_bc_value_ok,$(l),$(bc)))))
 #$(foreach l,$(pe),$(call check_param_ok,$(l)_mp))
 ifile_given=1
endif

all_fq_files=$(all_pe_files) $(all_se_files)
nfqfiles=$(words $(all_fq_files))
nfqfilesu=$(words $(sort $(all_fq_files)))

ifneq ($(nfqfiles),$(nfqfilesu))
$(call p_error,Some of the libraries provided in se and/or pe have the same filename)
endif
#$(call p_info,has_stranded_data=$(has_stranded_data))

ifndef ifile_given
$(warning pe parameter or se parameter should be defined and non-empty)
endif
endif
# endif  ($(MAKECMDGOALS),stage0)


#***********
# Contrasts
#***********

# backward compatibility
#ifdef conditions
#endif


ifdef contrasts
 $(info *	contrasts=$(contrasts))
# check contrast/group names
 $(foreach l,$(contrasts),$(call check_name,$(l),contrast);$(foreach g,$($(l)),$(call check_name,$(g),group/condition)))
 $(foreach l,$(contrasts),$(info *      $(l)=$($(l)));$(foreach g,$($(l)),$(call check_param_ok,$(g))))
else
contrasts=
endif


# Contrasts
# Ex.
# contrasts=contrast1 contrast2
# contrast1=g1 g2
# g1=Lib1 Lib2
# g2=Lib3 Lib4

########
# groups
# list of groups defined (only used during html report generation)
# ex.
# groups=group1 group2 group3 
ifndef groups
$(info *	 groups=  parameter not defined, this should be defined if you intend to generate an HTML report for the inferred gene/level/transcript quantification)
groups=
else
$(foreach g,$(groups),$(call check_param_ok,$(g)))
$(info *	groups=$(groups))
endif

#*********************
# Technical replicates
#*********************

# ex. technical.replicates=SE1,SE2;PE1,PE3,PE4
# means that there are two groups of tech. replicates (separated by;), group 1 composed by SE1 and SE2  and group2 composed by PE1,PE3 and PE4.
ifndef technical.replicates
technical.replicates=
 $(info *	technical.replicates=NONE)
else
 $(info *	technical.replicates=$(technical.replicates))
 # validate the libraries names
 comma=,
 quote="
 $(foreach  l,$(subst $(quote), ,$(subst $(comma), ,$(subst ;, ,$(technical.replicates)))),$(call check_param_ok,$(strip $(l))))
endif
#" 


#####################
# Other Optional parameters
#####################
$(info * )
$(info * Optional Parameters:)

## RNASeq type
SUPPORTED_RNASEQ_TYPES:=blk sc
ifeq (,$(filter $(rnaseq_type),$(SUPPORTED_RNASEQ_TYPES)))
$(call p_info,[ERROR] Invalid rnaseq_type - valid values are $(SUPPORTED_RNASEQ_TYPES))
$(error Invalid rnaseq_type)
endif
$(info *	rnaseq_type=$(rnaseq_type))

ifeq ($(rnaseq_type),sc)
## single cell protocol
SUPPORTED_SCP:=none smart-seq2 drop-seq 10x_v1 10x_v2
# drop-seq 10x
ifeq (,$(filter $(sc_protocol),$(SUPPORTED_SCP)))
$(call p_info,[ERROR] Invalid sc_protocol - valid values are $(SUPPORTED_SCP))
$(error Invalid sc_protocol)
endif
$(info *	sc_protocol=$(sc_protocol))

endif

################################################################
## single cell specific parameters

## Simple cell filter
## Cells with less or equal than $(sc_non_zero_rows) are discarded
sc_non_zero_rows=1
## increasing this filter can make the intermidiate files smaller but there is no track of the cells lost

## parameters passed to bam_umi_count (umi_count quant. option)
bam_umi_count_params?=--min_reads 0 --multi_mapped
## --uniq_mapped --multi_mapped
umis_params?=--cb_cutoff 2


########################
## single cell filtering
cell_filt_min_features?=0.35   # minimum number of features expressed as a percentage of the total number of features

cell_filt_max_ERCC?=0.8  # maximum percentage of expression that may be atributed to ERCC spike-ins

# pre-blacklisted cells
cell_filt_controls?=   # file with the a known list of cells that should not be used in downstream analysis

cell_filt_outliers?=y   # filter outliers based on the total number of counts (y|n)
## Exclude outliers based on the 5*median absolute difference (like scater).

cell_filt_min_expression?=1

cell_filt_min_cell_expr?=50000 # minimum number of counts per cell

########################
## Clustering
## Only used in sc mode
min_clusters?=2
max_clusters?=2
clustering_method:=sc3

# Optional two column tsv file with cell annotations 
# cells_samples_annotation=
#

# not used yet
# valid_clustering_methods=sc3

#********
# Threads
#********
ifndef max_threads
 max_threads=$(def_max_threads)
endif
$(info *	max_threads=$(max_threads))

#********************
# Temporary directory
#********************
# 
ifndef tmp_dir
 tmp_dir=$(data_dir)/tmp
endif

#$(shell mkdir -p tmp_dir)
$(info *	tmp_dir=$(tmp_dir) (temporary directory))

#******************
# Quality filtering
#******************
# on|off|report=none(deprecated)
ifdef qc
 qual_filtering=$(qc)
endif

ifndef qual_filtering
 qual_filtering=$(def_qual_filtering)
endif

ifndef cont_mapper
cont_mapper=$(def_cont_mapper)
endif

# alias
ifndef qc
qc=$(qual_filtering)
endif

# on - perform filtering of the reads
# report - just collect QC stats
# off - skip filtering and collection of QC stats
qc_modes=on off report
ifeq (,$(filter $(qc),$(qc_modes)))
$(call p_info,[ERROR] Invalid qc/qual_filtering value)
endif


ifndef trim_reads
 trim_reads=$(def_trim_reads)
endif


# Trim poly-A/T? y|n
trim_poly_at?=$(def_trim_poly_at)
# minimum poly-at length
# by default, if a read has at least 10 consecutive A or T in the edges then it will be trimmed. This option is only used if trim_poly_at is set to y
trim_poly_at_len?=$(def_trim_poly_at_len)


#*************
# Min. quality
#*************
ifdef min_read_quality
 ifeq ($(strip $(min_read_quality)),)
  undefine min_read_quality
 endif
endif

ifndef min_read_quality
 min_read_quality=$(def_min_read_quality)
endif

# Maximum (percentage) of uncalled bases acceptable in a read
max_n?=0

#*******************
# Contamination file
#*******************
ifndef cont_index
 cont_index=$(def_cont_index)
endif

#**************
# Mapper to use
#**************
ifndef mapper
 mapper=$(def_mapper)
endif
$(info *	mapper=$(mapper))

# gems
SUPPORTED_MAPPERS=tophat1 tophat2 smalt gsnap soapsplice bwa1 bwa2 bowtie1 bowtie2 gem star osa mapsplice hisat2
ifeq ($(rnaseq_type),sc)
SUPPORTED_MAPPERS+= kallisto 
endif

ifeq (,$(filter $(mapper),none $(SUPPORTED_MAPPERS)))
$(call p_info,[ERROR] Invalid mapper)
$(error $(mapper) not implemented)
endif

mapper:=$(strip $(mapper))
#***************************
# Quantification/Transcr. assembly program
#***************************
# Note: only reference based assemblers should be supported
# assembler (deprecated)
ifdef quant_method
undefine assembler
endif

ifdef assembler
ifndef quant_method
quant_method=$(assembler)
endif
ifndef quant_norm_tool
quant_norm_tool=$(assembler)
endif
endif

ifndef quant_norm_method
# ifndef quant_method
quant_norm_method=$(def_quant_norm_method)
# else
# quant_norm_method=none
# endif
endif



ifndef quant_norm_tool
quant_norm_tool=$(def_quant_norm_tool)
endif

###########################
# Method to count reads mapped to features (genes, exons, ...)
###########################
ifndef quant_method
 quant_method:=$(def_quant_method)
endif

SUPPORTED_QUANT_METHODS=basic htseq1 htseq2 cufflinks1 cufflinks2 cufflinks1_nd cufflinks2_nd scripture flux_cap nurd stringtie stringtie_nd rsem kallisto salmon umi_count umis 

# methods that produce transcript level quantification by default
TRANS_QUANT_METHODS=flux_cap cufflinks1 cufflinks2 cufflinks1_nd cufflinks2_nd nurd stringtie stringtie_nd rsem kallisto salmon umi_count bitseq
#umi_count kallisto_umi 
# umis?

#rsem isoem sailfish bitseq
ifeq (,$(filter $(quant_method),$(SUPPORTED_QUANT_METHODS) none))
$(call p_info,[ERROR] quant_method)
$(error $(quant_method) not supported)
endif

quant_method:=$(strip $(quant_method))	
$(info *	quant_method=$(quant_method))

ifndef exon_quant
exon_quant=$(def_exon_quant)
else
exon_quant:=$(strip $(exon_quant))
endif

ifndef exon_quant_method
exon_quant_method=dexseq
endif

ifndef transcript_quant
transcript_quant=$(def_transcript_quant)
ifneq (,$(filter $(quant_method),$(TRANS_QUANT_METHODS)))
$(info Enabling transcript_quant since  $(quant_method) supports it by default)
override transcript_quant:=y
endif
endif



$(info *	exon_quant=$(exon_quant))
ifeq ($(exon_quant),y)
$(info *	exon_quant_method=$(exon_quant_method))
endif
$(info *	transcript_quant=$(transcript_quant))


#####################
# Exon quantification
SUPPORTED_EXON_QUANT_METHODS=stringtie dexseq htseq1 htseq2


ifeq ($(strip $(exon_quant)),y) 
ifneq (,$(filter $(quant_method),cufflinks1 cufflinks2 cufflinks2_nd cufflinks1_nd nurd stringtie stringtie_nd rsem kallisto salmon))
$(error Sorry... currently $(quant_method) cannot be used together with exon_quantification)
endif

# dexseq can only be used with methods that do not support exon quant
ifeq ($(exon_quant_method),dexseq) 
ifneq (,$(filter $(quant_method),cufflinks1 cufflinks2 cufflinks2_nd cufflinks1_nd nurd stringtie stringtie_nd rsem kallisto salmon))
$(error Sorry... currently DEXSeq cannot be used together with $(quant_method))
endif
else 
ifneq (,$(filter $(exon_quant_method),cufflinks1 cufflinks2 cufflinks2_nd cufflinks1_nd nurd rsem kallisto salmon))
$(error $(exon_quant_method) does not provide exon level quantification)
endif
#$(info Exon quantification requires that all exons in the gtf file have an exon_id attribute)
endif
#exon_quant_method=$(quant_method)
#$(info *	exon_quant_method=$(exon_quant_method))
endif

ifndef gtf_file_wexonid
gtf_file_wexonid=$(gtf_file_abspath)
#$(gtf_file_wexonid)=$(gtf_file_abspath).exon_id.gtf
endif

##################################
# method to normalize the counts
##################################


SUPPORTED_NORM_TOOLS=cufflinks1 cufflinks2 cufflinks1_nd cufflinks2_nd flux_cap  nurd stringtie irap
ifeq (,$(filter $(quant_norm_tool),none $(SUPPORTED_NORM_TOOLS)))
$(call p_error,quant_norm_tool '$(quant_norm_tool)' invalid)
endif

ifeq ($(quant_norm_method),rpkm)
$(call p_error,quant_norm_method Please use fpkm instead of RPKM)
endif

# Normalization methods
SUPPORTED_NORM_METHODS=fpkm deseq_nlib tpm
# rpkm_qn
ifeq (,$(filter $(quant_norm_method),none $(SUPPORTED_NORM_METHODS)))
$(call p_error,quant_norm_method '$(quant_norm_method)' invalid)
endif



ifneq (,$(filter $(quant_method),cufflinks1 cufflinks2 cufflinks1_nd cufflinks2_nd nurd stringtie stringtie_nd flux_cap))
ifndef quant_norm_tool
quant_norm_tool=$(quant_method)
override quant_norm_method=fpkm
$(info * Enabling generation of table of FPKMs since $(quant_method) produces F/RPKMs by default)
endif
ifeq ($(quant_norm_tool),none)
quant_norm_tool=$(quant_method)
override quant_norm_method=fpkm
$(info * Enabling generation of table of FPKMs since $(quant_method) produces F/RPKMs by default)
endif
endif


$(info *	quant_norm_tool=$(quant_norm_tool))
$(info *	quant_norm_method=$(quant_norm_method))
#******************************
# Use unspliced mapping: yes/no 
#******************************
# this option is going to be removed in the future
ifndef mapper_splicing
 mapper_splicing=$(def_mapper_splicing)
endif
$(info *	mapper_splicing=$(mapper_splicing))

#********************
# DE
#********************
ifndef de_method
ifdef compare
de_method=$(compare)
endif
endif

ifndef de_method
 de_method=$(def_de_method)
endif

SUPPORTED_DE_METHODS=cuffdiff1 cuffdiff2 cuffdiff1_nd cuffdiff2_nd deseq edger voom deseq2
ifeq (,$(filter $(de_method),none $(SUPPORTED_DE_METHODS)))
$(call p_info,[ERROR] de_method)
$(error $(de_method) not supported)
endif

de_method:=$(strip $(de_method))
$(info *	de_method=$(de_method))

ifndef de_pvalue_cutoff=
 de_pvalue_cutoff=$(def_de_pvalue_cutoff)
endif
$(info *	de_pvalue_cutoff=$(de_pvalue_cutoff))

ifndef de_num_genes_per_table
de_num_genes_per_table=$(def_de_num_genes_per_table)
endif

# TSV file
# format (fields may be missing with NA)- (gene) ID is mandatory and should match the one given in the gtf file
# "ID","Name","locus","source","lname","GO","GOterm","KEGG"
ifndef annot_tsv
annot_tsv=$(def_annot_tsv)
#else
# TODO: check if file format is ok and file !=auto
endif

ifeq (auto,$(annot_tsv)) 
annot_tsv=$(name)/data/$(reference_basename).gene.annot.tsv
endif


ifeq (off,$(annot_tsv)) 
override annot_tsv:=$(name)/data/empty.gene.annot.tsv
endif


ifndef de_annot_genes_only
de_annot_genes_only=$(def_de_annot_genes_only)
endif

#$(info annot_tsv=$(annot_tsv))

###############################################
# isl enabled -> stage3 targets=stage4
ifeq ($(isl_mode),y)
$(info *	isl_mode enabled)
endif

#************
# Constraints
#************
ifdef compare_mappers
 ifdef conditions
  $(error Incompatible options: compare_mappers and conditions)
 endif
endif



ifeq ($(mapper_splicing),no)
 files_indexed=$(trans_file)
else
# word 1 = reference 
 files_indexed=$(reference_prefix) $(gtf_file_abspath)
endif

ifeq (y,$(de_annot_genes_only))
 ifeq ($(de_method),cuffdiff1)
  $(error Incompatible options: de_annot_genes_only & $(quant_method))
 endif
 ifeq ($(de_method),cuffdiff2)
  $(error Incompatible options: de_annot_genes_only & $(quant_method))
 endif
endif

##########
# other options

# maximum number of mappings allowed for each read
ifndef max_hits
 max_hits=$(def_max_hits)
endif

# fix NH flag in BAM files (y,n)
ifndef fix_NH
 fix_NH=$(def_fix_NH)
endif

#
# Htseq - produce a sam file with annotations?y/n
ifndef htseq_sam_output
htseq_sam_output=$(htseq_sam_output_def)
endif

ifeq ($(htseq_sam_output),y)
htseq_sam_output=
endif
#
# mem in MB
ifndef max_mem
max_mem=$(def_max_mem)
endif

# max memory in GB
max_mem_gb:=$(shell expr $(max_mem) \/ 1000)

# set memory (in bytes) to 65% of the max. memory available
#ifndef SAMTOOLS_SORT_MEM
# SAMTOOLS_SORT_MEM:=`expr $(max_mem) \* 1000000 \* 65 \/ 100`
#endif


# samtools 1.x
ifndef SAMTOOLS_SORT_MEM
 SAMTOOLS_SORT_MEM:=$(shell bash -c "expr $(max_mem_gb) \* 75 \/ 100")G
endif


ifndef feat_length
feat_length=$(name)/data/$(gtf_file_basename).lengths.Rdata
endif

ifndef exon_length
exon_length=$(name)/data/$(gtf_file_basename).lengths.Rdata
endif


##
## barcodes (umi, cell, sample)
barcode_post_process_bam?=n
$(info *	barcode_post_process_bam=$(barcode_post_process_bam))

# 1 - lib
# 2 - in bam
# 3 - out bam
ifeq ($(barcode_post_process_bam),y)
## alignments to the genome
define do_post_process_bam_cmd=
bam_add_tags  --inbam $(2) --outbam - | bam_annotate.sh -b - -e $(name)/data/$(reference_basename).exons.bed   -i $(name)/data/$(reference_basename).introns.bed  -g $(name)/data/$(reference_basename).genes.bed6 -t $(name)/data/$(reference_basename).transcripts.bed6 > $(3).tmp && mv $(3).tmp $(3)
endef
## Alignments to the transcriptome - assumes that the chr/seq contains the transcript ID
define do_post_process_trans_bam_cmd=
bam_add_tags --tx_2_gx $(mapTrans2gene) --tx  --inbam $(2) --outbam - > $(3).tmp && mv $(3).tmp $(3)
endef

else
define do_post_process_bam_cmd=
true 
endef
define do_post_process_trans_bam_cmd=
true 
endef
endif

###############################################################################
# When the number of libraries is greater than BIG_LIM then pass the arguments
# to some scripts from stdin
ifndef BIG_LIM
BIG_LIM:=400
endif

ifeq ($(shell expr $(words $(se) $(pe)) \<  $(BIG_LIM)),0)
# too many libs to be able to pass them as an argument
$(call p_info, Big number of libraries mode (>$(BIG_LIM)))
BIG_EXP=1
# cmd=$1
# out_file=$2
# args=$3
define pass_args_stdin=
$(call args2file,$(2).in,$(3)) cat $(2).in | $(1) -stdin && rm -f $(2).in
endef

else
BIG_EXP=0
#$(call p_info, Small number of libraries mode)
# cmd=$1
# out_file=$2
# args=$3
define pass_args_stdin=
$(1) $(3) 
endef

endif

################################################################################
# Make stuff
phony_targets=
silent_targets= 
precious_targets=

empty:=
space:=$(empty) $(empty)#
################################################################################
# AUXILIARY FUNCTIONS
################################################################################

# FALSE=empty

# return a string in the form of group1,group2,...
define groups2str=
$(call spaces2commas,$(call groupsnames))
endef

define remove_spaces=
$(subst $(space),,$(1))
endef

define spaces2commas=
$(shell echo $(1)|tr " " ",")
endef

#$(sort $(strip $(foreach l,$(groups),$(foreach g,$($(l)),$(g)))))
define groupsnames=
$(sort $(strip $(foreach l,$(groups),$(l) )))
endef


# return groups definition
define groupsdef2str=
$(call remove_spaces,$(foreach g,$(call groupsnames),$(call spaces2commas,$(strip $($(g))));))
endef

define libname2ofastq=
$($(1))
endef

# 1 - lib
# 2 - pe
define get_fastq_prefix=
$(if $(filter $(2),pe),$(subst _2,,$(subst _1,,$(basename $(word 1,$($(1)))))),$(basename $(word 1,$($(1)))))
endef

# fix the libname by excluding _1 and _2 from PE files
define fix_libname=
$(if $(call valid_libname,$(1)),$(1),$(call get_lib_name,$(1)))
endef

define valid_libname=
$(if $(filter $(strip $(1)),$(pe) $(se)),y)
endef

# 1 - libname
# return y if is PE '' otherwise
define is_pe_lib=
$(if $(filter $(strip $(1)),$(pe)),y)
endef

# 1-libname
# path to the filtered fastq files 
define libname2fastq=
$(if $(call is_pe_lib,$(1)),$(call lib2filt_folder,$(1))$(1)_1.f.fastq.gz $(call lib2filt_folder,$(1))$(1)_2.f.fastq.gz,$(call lib2filt_folder,$(1))$(1).f.fastq.gz)
endef

# 1-libname
define bam_file_for_lib=
$(if $(call is_pe_lib,$(1)),$(1).pe.hits.bam,$(1).se.hits.bam)
endef


define get_lib_name=
$(if $(filter $(1),$(se)),$(1),$(if $(findstring $(patsubst %_1,%,$(1)),$(pe)),$(patsubst %_1,%,$(1)),$(if $(findstring $(patsubst %_2,%,$(1)),$(pe)),$(patsubst %_2,%,$(1)),$(1))))
endef

# 1 -lib
define path2lib_bam=
$(call lib2bam_folder,$(1))/$(call bam_file_for_lib,$(1))
endef

# 1-group
define  get_group_bam_files=
$(foreach l,$($(1)), $(call path2lib_bam,$(l)))
endef

# save all variables defined in Make (filename)
define vars2file=
$(file > $(1))
$(foreach ivar,$(.VARIABLES),$(if $(filter $(origin $(ivar)),'file' 'command line',$(file >> $(1),$(ivar)=$($(ivar))))))
endef
#$(call vars2file,/tmp/lixo)

# the bam file names of each group are concatened using ,
define  get_contrast_bam_files=
$(foreach c,$($(1)), $(shell echo $(call get_group_bam_files,$(c)) | sed "s/ /,/g"))
endef

# 
define get_de_annot=
$(if $(annot_tsv),--annotation $(annot_tsv),)
endef

# DE options
define get_de_annot_genes_only=
$(if $(subst y,,$(de_annot_genes_only)),,--annot-genes-only)
endef

#1
define filename2libname=
$(foreach l,$(se) $(pe),$(if $(filter $(l).,$(1)),$(l)))
endef

# 1 tsv filename
#  exon, gene or CDS?
# DE filename to Analysis level
define DEfilename2AL=
$(if $(findstring .genes_de,$(1)),gene,$(if $(findstring .exons_de,$(1)),exon,CDS))
endef

define DEfilepath2demethod=
$(shell basename `dirname $(1)`)
endef

# sam/bam cat
# avoid samtools cat if there is only a file
# $(1)=files
define samcat=
$(if $(strip $(word 2,$(1))),samtools cat -o - $(1),cat $(1))
endef

# two line empty file (ensure that size !=0 and # lines >1)
# 1 - filename
define empty_file=
echo Empty	Empty > $(1) && echo Empty	Empty  >> $(1)
endef

# 1 - filename
# return y if it is an empty file or '' otherwise
define is_empty_file=
$(if  $(realpath $(1)),$(if $(shell head -n 1 $(1) | grep   Empty),y))
endef

define zero_lines_file=
$(if $(realpath $(1)),$(if  $(shell wc -l $(1)|cut -f 1 -d\ |sed "s/^0$//",,no)),)
endef
#1-file
#2-args
define args2file=
 $(file > $(1),$(2))
 $(shell echo >> $(1))
endef
# add the new line in the end

####################
###################
# 
# $(1) var name
cached_vars=

cached_vars_file=$(name)/cached_vars.mk
ifndef use_cached_vars
use_cached_vars=n
endif

define cached_var=
$(if $(call is_defined,$(1)), $(call p_debug,cache hit $(1)), $(call set_$(1)) $(call p_debug,cache miss $(1)) $(eval cached_vars+= $(1))) $($(1))
endef

ifeq (use_cached_vars,y)
$(call file_exists,$(cached_vars_file))	
include $(cached_vars_file)
$(info [INFO] Loaded cached variables.)
endif

#
define list_cached_vars=
	$(foreach var,$(cached_vars) cached_vars, echo $(var)=$(strip $(call cached_var,$(var)));)
endef


################################################################################
# Files produced at each stage
SETUP_DATA_FILES=
STAGE3_OUT_FILES=
STAGE2_OUT_FILES=
STAGE4_OUT_FILES=
STAGE5_OUT_FILES=

# STAGE3 library level targets
STAGE3_S_TARGETS=
# STAGE3 library level output files
STAGE3_S_OFILES=

##
STAGE1_OUT_FILES=$(foreach p,$(se),$(call lib2filt_folder,$(p))$(p).f.fastq.gz) $(foreach p,$(pe),$(call lib2filt_folder,$(p))$(p)_1.f.fastq.gz)

ifneq ($(mapper),none)

STAGE2_OUT_FILES=$(foreach p,$(pe), $(call lib2bam_folder,$(p))$(p).pe.hits.bam) $(foreach s,$(se), $(call lib2bam_folder,$(s))$(s).se.hits.bam)

STAGE2BYNAME_OUT_FILES=$(foreach p,$(pe), $(call lib2bam_folder,$(p))$(p).pe.hits.byname.bam) $(foreach s,$(se), $(call lib2bam_folder,$(s))$(s).se.hits.byname.bam)

else

STAGE2_OUT_FILES=
STAGE2BYNAME_OUT_FILES=

endif

bam_files=$(STAGE2_OUT_FILES)


################################################################################
# Load extra code
# shared code
# QC stats
include $(irap_path)/../aux/mk/irap_qc_stats.mk
# Mapping
include $(irap_path)/../aux/mk/irap_map.mk
# JBrowse
include $(irap_path)/../aux/mk/irap_jbrowse.mk
# HTML Reporting
include $(irap_path)/../aux/mk/irap_report.mk
# Software used (versions and citations)
include $(irap_path)/../aux/mk/irap_citations.mk
# Quantification
include $(irap_path)/../aux/mk/irap_quant.mk
include $(irap_path)/../aux/mk/irap_sc_quant.mk
# Normalization
include $(irap_path)/../aux/mk/irap_norm.mk
# DE
include $(irap_path)/../aux/mk/irap_de.mk
# Gene set enrichment analysis
include $(irap_path)/../aux/mk/irap_gse.mk

# Atlas (atlas specific stuff)
include $(irap_path)/../aux/mk/irap_atlas.mk

# Fusion
include $(irap_path)/../aux/mk/irap_fusion.mk

# QC - single cell
include $(irap_path)/../aux/mk/irap_sc_qc.mk
include $(irap_path)/../aux/mk/irap_clustering.mk


ifdef irap_devel
$(call p_info,Loading code under development)
# include under development features
include $(irap_path)/../aux/mk/irap_snp_indel_calling.mk
# Junctions
include $(irap_path)/../aux/mk/irap_junction.mk
endif

# Check if the options provided are valid
ifeq (invalid,$(shell irap_paths $(mapper) $(quant_method) $(quant_norm_tool) $(quant_norm_method) $(de_method) $(gse_tool) $(has_stranded_data) $(rnaseq_type) $(sc_protocol)))
  $(error invalid combination mapper:$(mapper) -> quant_method:$(quant_method) -> quant_norm method:$(quant_norm_method) quant_norm_tool:$(quant_norm_tool) -> de_method:$(de_method) rnaseq_type:$(rnaseq_type) sc_protocol:$(sc_protocol) for the given data)
endif

$(info *========================================================)

#################################################################################
ifneq ($(mapper),none)
index_files=$(call $(mapper)_index_filenames,$(word 1,$(files_indexed)),$(word 1,$(files_indexed)))
else
index_files=
endif

#*********************
# print all variables
ifdef debug
$(info DEBUG)
VARS2PRINT=reference_prefix gtf_file_abspath index_files files_indexed feat_mapping_file
$(foreach v,$(VARS2PRINT),$(info $v=$($v)))
endif
$(call p_info,[DONE] Initialization)


###################
# Quality Filtering
###################
read_qual_filter_common_params=tmp_dir=$(tmp_dir)  threads=$(max_threads)  qual_filtering=$(qual_filtering)  min_qual=$(min_read_quality) trim=$(trim_reads) cont_index=$(cont_index) mapper=$(cont_mapper) max_n=$(max_n) max_mem=$(max_mem) poly_at_len=$(trim_poly_at_len) trim_poly_at=$(trim_poly_at)

# get a param value pair iff the value passed is not empty and not undef
# 1 - param name
# 2 - value
get_param_value_pair=$(if $(call not_empty_not_undef,$(2)),$(1)$(2),)
not_empty_not_undef=$(if $(subst undef,,$(1)),1,)

# 1 - lib
define get_opt_barcode_params=
barcode_min_qual=$(barcode_min_qual) \
$(call get_param_value_pair,umi_read=,$(subst read,,$($(1)_umi_read))) $(call get_param_value_pair,umi_size=,$($(1)_umi_size))  $(call get_param_value_pair,umi_offset=,$($(1)_umi_offset)) \
$(call get_param_value_pair,cell_read=,$(subst read,,$($(1)_cell_read))) $(call get_param_value_pair,cell_size=,$($(1)_cell_size))  $(call get_param_value_pair,cell_offset=,$($(1)_cell_offset)) \
$(call get_param_value_pair,sample_read=,$(subst read,,$($(1)_sample_read))) $(call get_param_value_pair,sample_size=,$($(1)_sample_size))  $(call get_param_value_pair,sample_offset=,$($(1)_sample_offset)) \
 $(call get_param_value_pair,known_umi_file=,$($(1)_known_umi_file)) \
 $(call get_param_value_pair,index1=,$($(1)_index1)) \
 $(call get_param_value_pair,index2=,$($(1)_index2)) \
 $(call get_param_value_pair,read1_offset=,$($(1)_read1_offset))  $(call get_param_value_pair,read2_offset=,$($(1)_read2_offset)) \
 $(call get_param_value_pair,read1_size=,$($(1)_read1_size)) $(call get_param_value_pair,read2_size=,$($(1)_read2_size))
endef

# 1 - libname
# 2 - input folder
# 3 - output folder
# 4 - extra options
#s
define do_quality_filtering_and_report=
	irap_fastq_qc $(read_qual_filter_common_params) input_dir=$(2) read_size=$($(1)_rs)   qual=$($(1)_qual) f="$($(1))" out_prefix=$(1) is_pe=$(call is_pe_lib,$(1)) out_dir=$(3)  $(4) $(call get_opt_barcode_params,$(1))
endef
#	irap_fastq_qc $(read_qual_filter_common_params) data_dir=$(raw_data_dir)$($(1)_dir) read_size=$($(1)_rs)   qual=$($(1)_qual) f="$($(1))" out_prefix=$(1) is_pe=$(#call is_pe_lib,$(1)) out_dir=$(name)/data/$($(1)_dir)  $(2)
# report_dir=$(name)/report/riq/$($(1)_dir)

define not_empty=
	$(if $(call file_exists,$(1),),$(call p_error,File $(1) not found))
	$(if $(shell wc -l $(1)|cut -f 1 -d\ ),,$(call p_error,Empty file $(1)))
endef

################################################################################
#
################################################################################
# Generic file extension rules

# generate the fastq from BAM
# $(data_dir)/raw_data/$(species)/%.fastq: $(data_dir)/raw_data/$(species)/%.bam
# 	bamToFastq -i $^ -fq $@.tmp  && mv $@.tmp $@
# # pair-end data
# # bam files need to be sorted by name
# $(data_dir)/raw_data/$(species)/%_1.fastq $(data_dir)/raw_data/$(species)/%_2.fastq: $(data_dir)/raw_data/$(species)/%.bam
# 	$(call p_info,"Converting bam to fastq...note that the bam file needs to be sorted by name.")
# 	bamToFastq -i $^ -fq $*_1.fastq.tmp -fq2 $*_2.fastq.tmp && mv $*_1.fastq.tmp $*_1.fastq && mv $*_2.fastq.tmp $*_2.fastq

# uncompress rules
%.fa: %.fa.gz
	gunzip -c $< > $@.tmp && mv $@.tmp $@

%.fasta: %.fasta.gz
	gunzip -c $< > $@.tmp && mv $@.tmp $@

%.gtf: %.gtf.gz
	gunzip -c $< > $@.tmp && mv $@.tmp $@


ifdef spikein_data

$(reference_abspath): $(user_reference_abspath) $(spikein_fasta_abspath)
	cat $^ > $@.tmp && mv $@.tmp $@

$(spikein_gtf_file): $(spikein_fasta_abspath) 
	spikein_fasta2gtf.pl $< > $@.tmp && mv $@.tmp $@

$(gtf_file_abspath): $(user_gtf_abspath) $(spikein_gtf_file)
	cat $^ > $@.tmp && mv $@.tmp $@
endif


# give an error (should never happen)
#%.gtf:
#	$(call p_error, Missing gtf file $@)
# nf
%.gtf.irap.stats: %.gtf
%.gtf.irap.stats: %.gtf.gz



%.gtf.checked: %.gtf
	irap_check_gtf $(gtf_file_abspath) &&  touch $@

%.gtf.bed: %.gtf
	gtf2bed.pl $< > $@

%.bam.bedGraph: %.bam $(name)/data/$(reference_basename).chr_sizes.txt
	bedtools  genomecov -ibam $< -bg -g $(name)/data/$(reference_basename).chr_sizes.txt > $@.tmp && mv $@.tmp $@

# gtf file with exon_id attribute
%.gtf.exon_id.gtf: %.gtf %.gtf.checked
	gtf_add_exon_id.pl $< > $@.tmp && mv $@.tmp $@


# sort a bam file by name and index
%.byname.bam: %.bam
	rm -f $*.byname.tmp.{0,1,2,3,4,5,6,7,8,9}*.bam && samtools sort -n -m $(SAMTOOLS_SORT_MEM) -T $*.byname.tmp -o $*.byname.tmp.bam $< && mv $*.byname.tmp.bam $@ 

# index a bam file
%.bam.bai: %.bam
	samtools index $<
# samtools 1.1 does not support the second argument :(
#	samtools index $< $@.tmp && mv $@.tmp $@

%.cram: %.bam
	samtools view -C -T $(reference_abspath) $< > $@.tmp && mv $@.tmp $@

#
# bigWig from bed 
# bed file needs to be sorted and converted to bedGraph
%.bw: %.bed $(name)/data/$(reference_basename).chr_sizes.txt
	tail -n +2 $< | cut -f 1,2,3,5 | sort -k1,1 -k2,2n  > $<.sorted.bed && \
	bedGraphToBigWig $<.sorted.bed $(name)/data/$(reference_basename).chr_sizes.txt $@.tmp && mv $@.tmp $@

# bigwig from bedgraph
%.bw: %.bedGraph $(name)/data/$(reference_basename).chr_sizes.txt
	bedGraphToBigWig $< $(name)/data/$(reference_basename).chr_sizes.txt $@.tmp && mv $@.tmp $@

define quant_levelFromFilename=
$(if $(findstring exons,$(1)),exon,$(if $(findstring genes,$(1)),gene,mRNA))
endef

# TSV (with feature value) is converted to bedGraph (http://genome.ucsc.edu/goldenPath/help/bedgraph.html)
# bedGraph generated is sorted
%.bedGraph: %.tsv $(gff3_file_abspath).csv $(name)/data/$(reference_basename).chr_sizes.txt
	tsv2bed.R $<  $(call quant_levelFromFilename,$*) $(gff3_file_abspath).csv $(name)/data/$(reference_basename).chr_sizes.txt | \
	sort -k1,1 -k2,2n | \
	bedtools merge -scores mean -i - > $@.tmp &&\
	mv $@.tmp $@

# give an error
%.cdna.fa:
	$(call p_error,Missing cdna file $@)

# feat_mapping_file
%.mapping.Rdata %.mapping_exons.tsv %.mapping_trans.tsv: %.gtf
	irap_gtf2mapping --gtf $(gtf_file_abspath) --out $*.mapping.tmp --cores $(max_threads) && \
	mv $*.mapping.tmp.Rdata $*.mapping.Rdata && \
	mv $*.mapping.tmp_exons.tsv $*.mapping_exons.tsv && \
	mv $*.mapping.tmp_trans.tsv $*.mapping_trans.tsv 

# rename does not work on some distros :(
#	rename $*.mapping.tmp $*.mapping $*.mapping.*


################################################################################
# stage 0 - setup/initialization
setup: setup_dirs setup_files

phony_targets+= setup setup_files

################################################################################
# Setup initial files
# file with the length of the features (gene, isoform, exon)
SETUP_DATA_FILES+= setup_data_files2 $(name)/data/$(gtf_file_basename).gene_class.txt $(index_files) $(gtf_file_abspath).checked  $(gtf_file_abspath).exon_id.gtf $(juncs_file_abspath)   $(annot_tsv)  $(name)/data/$(reference_basename).introns.bed  $(name)/data/$(reference_basename).genes.bed6 $(name)/data/$(reference_basename).transcripts.bed6

setup_data_files2: $(gff3_file_abspath).filt.gff3 $(name)/data/$(reference_basename).$(gtf_file_basename).data_info.tsv 
#phony_targets+=setup_data_files2

# TODO: move $(name)/data/$(reference_basename).chr_sizes.sorted.txt to $(name)/data/$(reference_basename).chr_sizes.txt
# No need to include these files since they are generated by some rule
# $(name)/data/introns.bed -> $(name)/data/genes.bed $(name)/data/exons.bed 
# $(gff3_file_abspath).csv -> $(gff3_file_abspath) 

setup_files: $(SETUP_DATA_FILES)

print_stage0_files: setup_dirs
	echo $(SETUP_DATA_FILES)

ifneq ($(mapper),none)
# index the reference
$(word 1,$(index_files)): $(files_indexed)
	$(call p_info,INDEXING)
	$(call run_$(mapper)_index,$(word 1,$(files_indexed)))
ifneq ($(word 2,$(index_files)),)
# index the annotation/transcriptome
$(word 2,$(index_files)): $(files_indexed)
	$(call p_info,INDEXING 2)
	$(call run_$(mapper)_index_annot,$(word 1,$(files_indexed)))
endif
endif

# Create the file with gene classification by GeneId
$(refgeneclass_file): $(gtf_file_abspath)
	gtf2geneclass.sh $< > $@.tmp && mv $@.tmp  $@
#	$(error Missing required file $@)

# use tophat to generate the juncs file
# .gtf.juncs: .gtf
# note: the file may be empty
# in this case gtf2juncs returns an error that is ignored
$(juncs_file_abspath): $(gtf_file_abspath)
	tophat2_gtf_juncs $< > $@.tmp 
	mv $@.tmp $@

#
# .gff3.csv: .gff3
$(gff3_file_abspath): $(gtf_file_abspath)
	gtf2gff3.pl $< | sort -k1,1 -k4,4n > $@.tmp && mv $@.tmp $@

# Filter the gff3 file to contain only the chr that are in the fasta file
# use the faidx file to ensure that the ordering is the same
$(gff3_file_abspath).filt.gff3: $(gff3_file_abspath) $(name)/data/$(reference_basename).chr_sizes.sorted.bed 
#$(name)/data/$(reference_basename).chr_sizes.sorted.txt
	bedtools intersect -wa -a $(gff3_file_abspath) -b $(name)/data/$(reference_basename).chr_sizes.sorted.bed  > $@.tmp &&  bedtools sort -faidx $(name)/data/$(reference_basename).chr_sizes.sorted.bed  -i $@.tmp > $@.tmp2 && mv $@.tmp2 $@ && rm -f $@.tmp


# 
$(gff3_file_abspath).csv: $(gff3_file_abspath)
	gff32csv.R $<   >   $@.tmp && mv $@.tmp $@

#$(name)/data/$(reference_basename).gene_class.txt: $(refgeneclass_file)
$(name)/data/$(gtf_file_basename).gene_class.txt: $(refgeneclass_file)
	cp $< $@.tmp && mv $@.tmp $@

# file with chr\tchr_size
$(name)/data/$(reference_basename).chr_sizes.txt: $(reference_abspath).fai
	cut -f 1,2 $< > $@.tmp && mv $@.tmp $@

#######################################################
# Collect some stats about the reference and annotation
data_stats: $(name)/data/$(reference_basename).$(gtf_file_basename).data_info.tsv

print_data_stats_file:
	@echo $(name)/data/$(reference_basename).$(gtf_file_basename).data_info.tsv

$(name)/data/$(reference_basename).$(gtf_file_basename).data_info.tsv: $(name)/data/$(reference_basename).irap_stats.tsv $(name)/data/$(gtf_file_basename).irap_stats.tsv
	echo "Species|$(species)" | tr "|" "\n" > $@.tmp2
	echo "Genome|$(reference_basename)" | tr "|" "\n" > $@.tmp3
	paste $@.tmp2 $@.tmp3 $^   > $@.tmp && mv $@.tmp $@ && rm -f $@.tmp2 $@.tmp3

$(name)/data/$(reference_basename).irap_stats.tsv: $(name)/data/$(reference_basename).chr_sizes.txt
	irap_genome_stats -i $< -o $@.tmp && mv $@.tmp $@

$(name)/data/$(gtf_file_basename).irap_stats.tsv: $(name)/data/$(gtf_file_basename).lengths.Rdata
	irap_annot_stats -i $< -o $@.tmp && mv $@.tmp $@

#########################################################

# temporary rule:
# remove $(name)/data/$(reference_basename).chr_sizes.sorted.txt
# and rename to  $(name)/data/$(reference_basename).chr_sizes.txt
$(name)/data/$(reference_basename).chr_sizes.sorted.txt: $(name)/data/$(reference_basename).chr_sizes.txt
	sort -k 1,1 $<  > $@.tmp  && mv $@.tmp $@

$(name)/data/$(reference_basename).chr_sizes.sorted.bed: $(name)/data/$(reference_basename).chr_sizes.sorted.txt
	cat $< | awk 'BEGIN {OFS="\t";} {print  $$1,"1",$$2;}' > $@.tmp && mv $@.tmp $@

$(reference_abspath).fai: $(reference_abspath)
	samtools faidx $< && sleep 1

#ifeq ($(realpath ,)
# automatically generated annot file
# avoid generating file if it is in the reference directory
# Create a Rdata file to speedup loading the matrix 
$(refgeneannot_file) $(refgeneannot_file).Rdata: $(gtf_file_abspath)
	irap_gtf2annot --gtf $< -s $(species) --cores $(max_threads) --rdata -o $@.tmp && mv $@.tmp $@ && mv $@.tmp.Rdata $@.Rdata

$(name)/data/$(reference_basename).gene.annot.tsv: $(refgeneannot_file) 
	cp $< $@.tmp && mv $@.tmp $@

$(name)/data/$(reference_basename).gene.annot.tsv.Rdata: $(refgeneannot_file).Rdata
	cp $< $@.tmp && mv $@.tmp $@
#endif

$(name)/data/empty.gene.annot.tsv: 
	echo '"ID","Name","locus","source","lname","GO","GOterm","KEGG","biotype"' | tr "," "\t" > $@

# collect genes, transcripts and exons lengths
# generate only once
$(gtf_file_abspath).lengths.Rdata: $(gtf_file_abspath)
	irap_gtf2featlength --gtf $< -o $@.tmp --cores $(max_threads) && mv $@.tmp.Rdata $@ && mv $@.tmp.gene_length.tsv $@.gene_length.tsv && mv $@.tmp.exon_length.tsv $@.exon_length.tsv && mv $@.tmp.trans_length.tsv $@.trans_length.tsv


$(name)/data/$(gtf_file_basename).lengths.Rdata: $(gtf_file_abspath).lengths.Rdata
	sleep 2 && cp $< $@.tmp && mv $@.tmp $@ 

precious_targets+=$(name)/data/$(gtf_file_basename).lengths.Rdata

$(gtf_file_abspath).DEXSeq.gff.lengths.Rdata: $(gtf_file_abspath).DEXSeq.gff
	irap_DexSeqExonLen --gff $< -o $@.tmp --cores $(max_threads) && mv $@.tmp.Rdata $@

# sleep to ensure that the file will not have the same timestamp
$(name)/data/$(gtf_file_basename).dexseq.lengths.Rdata: $(gtf_file_abspath).DEXSeq.gff.lengths.Rdata
	sleep 2 && cp $< $@.tmp && mv $@.tmp $@



# $(trans_file): 
# 	$(call p_error,Missing trans_file = $(trans_file))

################################################################################
# Setup directory structure
phony_targets+= setup_dirs

setup_dirs: $(tmp_dir) $(name)/report/riq/ $(if $(mapper),$(name)/$(mapper)/) $(name)/data/  $(if $(quant_method),$(name)/$(mapper)/$(quant_method)/)  $(if $(de_method),$(name)/$(mapper)/$(quant_method)/$(de_method)/) $(name)/data/pre
	$(call p_info,[DONE] Directory structure created)

$(tmp_dir):
	mkdir -p $@

# really required?
#$(data_dir)/data:
#	mkdir -p $@


$(name)/data/:
	mkdir -p $@

$(name)/data/pre:
	mkdir -p $@

$(name)/report/riq/:
	mkdir -p $@

$(name)/$(mapper)/:
	mkdir -p $@

$(name)/$(mapper)/$(quant_method)/:
	mkdir -p $@

$(name)/$(mapper)/$(quant_method)/$(de_method)/:
	mkdir -p $@



################################################################################
# Read Filtering
################################################################################
# reuse the data filtered between experiments?
phony_targets+= qc quality_filtering_and_report clean_quality_filtering_and_report_cleanup

ifdef min_read_len
	read_qual_filter_common_params+=min_len=$(min_read_len)
endif

# alias: stage1=qc=quality_filtering_and_report
qc: quality_filtering_and_report 

# TODO: improve robustness (no filtered reads)
# TODO:	signature=filtering parameters (if they are the same then avoid recomputation between experiments)  minlen=$(min_read_len) min_qual=$(min_qual) qual_perc=$(min_qu
quality_filtering_and_report: setup	$(STAGE1_OUT_FILES)
	$(call p_info,[DONE] Quality filtering)

phony_targets+= do_qc
do_qc: $(STAGE1_OUT_FILES)

####################################################################
# Preprocessing of the input files (.fastq/.bam), QC, filtering

define make-pe-qc-rule=
$(info $(call lib2filt_folder,$(1))$(1)_1.f.fastq.gz $(call lib2filt_folder,$(1))$(1)_2.f.fastq.gz: $(raw_data_dir)$($(1)_dir)/$(word 1,$($(1)))  $(raw_data_dir)$($(1)_dir)/$(word 2,$($(1))))
$(call lib2filt_folder,$(1))$(1)_1.f.fastq.gz $(call lib2filt_folder,$(1))$(1)_2.f.fastq.gz: $(raw_data_dir)$($(1)_dir)/$(word 1,$($(1)))  $(raw_data_dir)$($(1)_dir)/$(word 2,$($(1)))
	$$(call p_info,Filtering $(call fix_libname,$(1)))
	$$(call do_quality_filtering_and_report,$(call fix_libname,$(1)),$(raw_data_dir)$($(1)_dir),$$(@D),) || (rm -f $$@ && exit 1)
endef

define make-se-qc-rule=
$(info $(call lib2filt_folder,$(1))$(1).f.fastq.gz: $(raw_data_dir)$($(1)_dir)/$($(1)))
$(call lib2filt_folder,$(1))$(1).f.fastq.gz: $(raw_data_dir)$($(1)_dir)/$($(1))
	$$(call p_info,Filtering $(call fix_libname,$(1)))
	$$(call do_quality_filtering_and_report,$(1),$(raw_data_dir)$($(1)_dir),$$(@D),) || (rm -f $$@ && exit 1)

endef
$(foreach l,$(se),$(eval $(call make-se-qc-rule,$(l))))
# rules for PE libraries
$(foreach l,$(pe),$(eval $(call make-pe-qc-rule,$(l))))


# Cleanup
clean_quality_filtering_and_report_cleanup:
	$(foreach p,$(se) $(pe),$(call do_quality_filtering_and_report,$(p),$(raw_data_dir)$($(p)_dir)/,$(dir $(call lib2filt_folder,$(p))),clean))


# TODO: deprecated
print_qc_dirs_files:
	echo	$(foreach l,$(se) $(pe),$(name)/report/riq/$($(l)_dir) )

################################################################################
# Mapping
################################################################################
# All mapping files have the same name (but are placed in different folders)
# The mappings are placed in $(name)/$(mapper) with the suffix (se/pe)hits.bam

# ** TODO **
# 1. Use singleton reads if available  (f.sing.fastq file)
# 2. make mapping independent from the remaining steps...WIP

mapping: stage1 $(name)/$(mapper)/ $(mapper)_mapping
	$(call p_info,[DONE] Mapping)

print_stage2_files:
	echo $(STAGE2_OUT_FILES)

#*************
# Generic rule
#*************
#####################
phony_targets+= $(mapper)_mapping mapping stage2_tracks

ifeq ($(mapper),none)
$(mapper)_mapping: 
else
$(mapper)_mapping: $(index_files) $(STAGE2_OUT_FILES)
endif

stage2_tracks_targets=$(call rep_browse,$(subst .bam,.bam.tracks,$(STAGE2_OUT_FILES)))	

stage2_tracks: $(stage2_tracks_targets)
	$(call p_info,[DONE] Generated stage 2 tracks)

stage2_upload_tracks: $(subst .tracks,.tracks.uploaded,$(stage2_tracks_targets))
	$(call p_info,[DONE] Uploaded stage 2 tracks)

# 
mappingbyname: $(mapper)_mappingbyname

$(mapper)_mappingbyname: $(index_files) $(STAGE2BYNAME_OUT_FILES)

# interleaved fastq file
# special rule for GEM with PE
# 1-mapper
define mapper_ifiles=
$(if $(subst gem,,$(1)),$(3),$(name)/data/$(2)_int.f.fastq)
endef

##############################################
# Create the rules on the fly for each library
# $1 = libname


define make-se-bam-rule=
ifeq ($(mapper),star)
$(call lib2bam_folder,$(1))$(1).se.hits.bam.trans.bam: $(call lib2bam_folder,$(1))$(1).se.hits.bam
endif
$(call lib2bam_folder,$(1))$(1).se.hits.bam: $(call lib2filt_folder,$(1))$(1).f.fastq.gz $(index_files) $(gtf_file_abspath) $(reference_prefix) 
	$(call run_$(mapper)_map,$(1),$$<,$$@)
endef



define make-pe-bam-rule=
ifeq ($(mapper),star)
$(call lib2bam_folder,$(1))$(1).pe.hits.bam.trans.bam: $(call lib2bam_folder,$(1))$(1).pe.hits.bam
endif
$(call lib2bam_folder,$(1))$(1).pe.hits.bam: $(call mapper_ifiles,$(mapper),$(1),$(call lib2filt_folder,$(1))$(1)_1.f.fastq.gz $(call lib2filt_folder,$(1))$(1)_2.f.fastq.gz)   $(index_files)
	$(call run_$(mapper)_map,$(1),$(call mapper_ifiles,$(mapper),$(1),$(call lib2filt_folder,$(1))$(1)_1.f.fastq.gz $(call lib2filt_folder,$(1))$(1)_2.f.fastq.gz),$$@)
endef


# create the output directories
ifneq ($(mapper),none)
$(foreach l,$(se) $(pe),$(eval $(shell mkdir -p $(call lib2bam_folder,$(l)))))

# rules for SE libraries
$(foreach l,$(se),$(eval $(call make-se-bam-rule,$(l))))
# rules for PE libraries
$(foreach l,$(pe),$(eval $(call make-pe-bam-rule,$(l))))
endif

# interleaved fastq file
$(name)/data/%_int.f.fastq: $(name)/data/%_1.f.fastq $(name)/data/%_2.f.fastq
	fastq2interleaved.pl $^ $@.tmp && mv $@.tmp $@

%.$(mapper).index: %.fa

################################################################################
# Quantification
################################################################################

define genes_quant_files=
$(foreach p,$(pe), $(call lib2quant_folder,$(p))$(p).pe.genes.raw.$(quant_method).tsv) $(foreach s,$(se), $(call lib2quant_folder,$(s))$(s).se.genes.raw.$(quant_method).tsv)
endef

define exons_quant_file=
$(if $(filter y,$(exon_quant)),$(name)/$(mapper)/$(quant_method)/exons.raw.$(exon_quant_method).tsv,)
endef

define exons_quant_files=
$(if $(filter y,$(exon_quant)),$(foreach p,$(pe),$(call lib2quant_folder,$(p))$(p).pe.exons.raw.$(exon_quant_method).tsv) $(foreach s,$(se), $(call lib2quant_folder,$(s))$(s).se.exons.raw.$(exon_quant_method).tsv),)
endef


define exons_quant_norm=
$(if $(filter y,$(exon_quant)),$(1),)
endef

#$(if $(filter y,$(transcript_quant)),$(name)/$(mapper)/$(quant_method)/transcripts.raw.$(quant_method).tsv,)

define transcripts_quant_norm=
$(if $(filter y,$(transcript_quant)),$(1),)
endef



# Note
# The quantification may be produced at the level of genes, exons  or transcripts/isoforms
ifeq ($(quant_method),none) 
quantification:
	$(call p_info,[DISABLED] Assembly and quantification)
$(quant_method)_quant_files=
$(quant_method)_quant:
quantification_s:

else
###################################
# quantification enabled
###################################
$(quant_method)_quant_files=$(name)/$(mapper)/$(quant_method)/genes.raw.$(quant_method).tsv $(call transcripts_quant_file)  $(call exons_quant_file) 

STAGE3_S_TARGETS+=$(call genes_quant_files) $(call transcripts_quant_files)  $(call exons_quant_files)


# Raw  + Normalized 
quantification: norm_quant $(quant_method)_quant 
	$(call p_info,[DONE] Assembly and quantification)

$(quant_method)_quant: mapping $($(quant_method)_quant_files)
# do not create the final matrix file (used by lsf wrapper)
quantification_s: $(STAGE3_S_TARGETS)

# $(STAGE3_S_TARGETS)
print_stage3_s_targets: 
	echo $(STAGE3_S_TARGETS)

###################################
# quantification enabled/end
###################################
endif
phony_targets+= quantification $(quant_method)_quant quantification_s
STAGE3_OUT_FILES+=$($(quant_method)_quant_files) 


#*****************
# Scripture 
#*****************

ifndef scripture_params
scripture_params= -minSpliceSupport 1
endif

define scripture_pe_file=
$(if $(strip $(pe)),$(1).paired.bam,)
endef

define scripture_pe_params=
$(if $(strip $(pe)),-pairedEnd $(1),)
endef
# run scripture for each chr
# extract the sequences
#                 1     2            3          4           5             6              7
# run_scripture (sam,tsv file,reference_dir,target_dir,pairend_option,annot.gtf,tsv file@extended bed)
define run_scripture=
	mkdir -p $(4)
	for chr in `cut -f 1 $(2)`; do  \
		scripture  $(scripture_params) -alignment $(1) -out $(4)/$$chr.segments -sizeFile $(2) -chr $$chr  -chrSequence $(3)/$$chr.fa $(5); \
	    scripture  -task score -in  $(4)/$$chr.segments -alignment $(1) -sizeFile $(2) -out $(4)/$$chr.score.tsv $(5);\
	done; 
	cat $(4)/*.score.tsv > $(7).tmp  && bedtools intersect -wb -b $(6) -a $(7).tmp | cut -f 15,29- | sed -e "s/^\([0-9]*\).0.\(.*\)/\2\t\1/" > $(7).tmp2 &&\
	irap_naive_count.pl $(7).tmp2 $(7).exons $(7).genes && \
	mv $(7).exons $(7).exons.tsv && \
	mv $(7).genes $(7).genes.tsv  && \
	grep -v -e "(`cut -f 1 $(7).exons.tsv|sed 's/ /|/g'`)" $(gtf_file_abspath)| sed  "s/.*gene_id .\([^\"]*\).;.*/\1\t0/" >>  $(7).genes $(7).genes.tsv 
endef

phony_targets+= scripture_quant scripture_assembly scripture_setup scripture_assembly_lsf1

scripture_quant: mapping $(name)/$(mapper)/scripture/rawcounts.scripture.tsv
	$(call p_error,scripture assembly is working (use target scripture_assembly) but quantification is still under development)
#
# as recommend by scripture manual
scripture_assembly: $(name)/$(mapper)/scripture/rawcounts.all.scripture.tsv

scripture_setup: $(name)/$(mapper)/$(quant_method)/$(reference_basename).chr_size.tsv $(reference_abspath)_files

# only generate the bam files for each lib
scripture_assembly_lsf1: $(foreach p,$(pe),$(name)/$(mapper)/$(quant_method)/$(p).pe.$(quant_method).tsv) $(foreach s,$(se), $(name)/$(mapper)/$(quant_method)/$(s).se.$(quant_method).tsv)

$(name)/$(mapper)/scripture/rawcounts.all.scripture.tsv:  $(gtf_file_abspath) $(name)/$(mapper)/$(quant_method)/alignments.bam $(name)/$(mapper)/$(quant_method)/$(reference_basename).chr_size.tsv $(reference_abspath)_files    $(call scripture_pe_file,$(name)/$(mapper)/$(quant_method)/alignments.bam) 
	mkdir -p $(@D)/all
	$(call run_scripture,$(@D)/alignments.bam,$(@D)/$(reference_basename).chr_size.tsv,$(reference_abspath)_files,$(@D)/all, $(call scripture_pe_params,$(call scripture_pe_file,$(@D)/alignments.bam)),$(gtf_file_abspath),$@.tmp) && mv $@.tmp.genes.tsv $@


#
# for DE and normalization it may be better to have the counts file by file
$(name)/$(mapper)/scripture/rawcounts.scripture.tsv: $(foreach p,$(pe),$(name)/$(mapper)/$(quant_method)/$(p).pe.$(quant_method).tsv) $(foreach s,$(se), $(name)/$(mapper)/$(quant_method)/$(s).se.$(quant_method).tsv)
	( $(call pass_args_stdin,irap_merge_tsv.sh,$@,$^) ) > $@.tmp && mv $@.tmp $@

# SE & PE
$(name)/$(mapper)/scripture/%.se.scripture.tsv: $(name)/$(mapper)/%.se.hits.bam $(gtf_file_abspath) $(name)/$(mapper)/$(quant_method)/$(reference_basename).chr_size.tsv $(reference_abspath)_files   $(name)/$(mapper)/%.se.hits.bam.bai
	$(call run_scripture,$<,$(@D)/$(reference_basename).chr_size.tsv,$(reference_abspath)_files,$(@D)/$*,,$(gtf_file_abspath),$@.tmp) && mv $@.tmp.genes.tsv $@

$(name)/$(mapper)/scripture/%.pe.scripture.tsv: $(name)/$(mapper)/%.pe.hits.bam $(gtf_file_abspath) $(name)/$(mapper)/$(quant_method)/$(reference_basename).chr_size.tsv $(reference_abspath)_files   $(name)/$(mapper)/%.pe.hits.bam.bai
	$(call run_scripture,$<,$(@D)/$(reference_basename).chr_size.tsv,$(reference_abspath)_files,$(@D)/$*, -pairedEnd $<,$(gtf_file_abspath),$@.tmp) && mv $@.tmp.genes.tsv $@


$(name)/$(mapper)/$(quant_method)/alignments.bam: $(foreach p,$(pe),$(name)/$(mapper)/$(p).pe.hits.byname.bam) $(foreach s,$(se),$(name)/$(mapper)/$(s).se.hits.byname.bam)
	$(call samcat,$^) | samtools sort -m $(SAMTOOLS_SORT_MEM) -T $@.sorted -o $@.sorted.bam -  && mv  $@.sorted.bam $@  && samtools index $@


$(name)/$(mapper)/$(quant_method)/alignments.bam.paired.bam: $(foreach p,$(pe),$(name)/$(mapper)/$(p).pe.hits.byname.bam)
	$(call samcat,$^) | samtools sort  -m $(SAMTOOLS_SORT_MEM) -T $@.tmp -o $@.tmp.bam -  && mv $@.tmp.bam $@ && samtools index $@

#
#A 2-column tab separated file containing the chromosome name and size for the organism.
$(name)/$(mapper)/$(quant_method)/$(reference_basename).chr_size.tsv: $(reference_abspath).fai
	cut -f 1,2 $< > $@.tmp && mv $@.tmp $@

$(reference_abspath)_files: $(reference_abspath)
	irap_fasta_split.pl $< $@

$(name)/$(mapper)/scripture/genes.raw.scripture.tsv: $(name)/$(mapper)/scripture/rawcounts.scripture.tsv
	cp $< $@

################################################################################
# STAGE 3
################################################################################

STAGE3_TSV_FILES+=$(call exons_quant_files)\
	       $(call transcripts_quant_files)\
	       $(call genes_quant_files)

##################
#

print_stage3_files:
	echo $(sort $(STAGE3_OUT_FILES))

print_stage3_s_files:
	echo $(sort $(STAGE3_S_OFILES))



################################################################################
# Stage 4
################################################################################

phony_targets+= print_stage4_files

print_stage4_files:
	echo $(STAGE4_OUT_FILES)

phony_targets+= print_stage5_files
print_stage5_files:
	echo $(STAGE5_OUT_FILES)

#############################################################
# GSE
###########################################
# IRAP targets
# todo: mv this to the irap_gse file

#############################################################
## Cleanup
phony_targets+= clean full_clean clean_data_files

clean: clean_quality_filtering_and_report_cleanup 

full_clean: clean_data_files
	rm -fr $(name)/

clean_data_files:
	rm -rf $(SETUP_DATA_FILES) $(index_files) $(reference_abspath).fa


# delete all files related to the libraries
lib_full_clean: clean_quality_filtering_and_report_cleanup 
	rm -rf $(STAGE1_OUT_FILES)
	$(foreach l,$(se) $(pe), $(if $($(l)_dir), rm -rf $(name)/data/$($(l)_dir)))
	rm -rf $(STAGE2_OUT_FILES)
	$(foreach l,$(se) $(pe), $(if $($(l)_dir), rm -rf $(name)/$(mapper)/$($(l)_dir)))
	rm -rf $(STAGE3_OUT_FILES)
	$(foreach l,$(se) $(pe), $(if $($(l)_dir), rm -rf $(name)/$(mapper)/$(quant_method)/$($(l)_dir)))

# TODO: archive (delete everything except the "main" output files for each stage
#
#############################################################
################################################################################
phony_targets+= stage0 stage1 stage2 stage3 stage3a stage3as stage3b stage4 stage5
silent_targets+= 

# alias - make it easier for the user
stage0: setup
stage1: setup quality_filtering_and_report
stage2: setup mapping
stage3: setup $(STAGE3_OUT_FILES)
stage3a: setup $(quant_method)_quant 
stage3as: setup quantification_s
#stage3b: setup stage3a
# deprecated
stage3b: setup $(shell rm -f $(name)/$(mapper)/$(quant_method)/rawcounts.$(quant_method).tsv) stage3a
stage4: setup $(STAGE4_OUT_FILES)
stage5: setup $(STAGE5_OUT_FILES)

# deprecated: to be removed in the future
assemble: quantification


# *************
# Transcriptome (WIP)
# *************
%.trans.fa: $(reference_abspath) %.ref.gtf
	extract_transcripts $^ > $@

%.cdna_ncrna.fa: %.cdna.all.fa %.ncrna.fa
	cat $^ > $@

%.ref.gtf: %.gtf %.ncrna.fa
	filterGTF.rb  $*.ncrna.fa $< > $@

%.ref.gtf: %.ref.gff
	ensembl_gtf_to_gff.pl $< > $@

##############################################################################
# Reporting

phony_targets+= report
report: report_all_targets

###################################################
# Execution status
# Creates a status.tsv file with the completion status of each stage of the pipeline based on the files created
phony_targets+= status_html status stage2_tracks stage3_tracks stage4_tracks
status_html: $(name)/report/status.html
	$(call p_info,Created $<)

status: $(name)/$(name).status.tsv
	$(call p_info,Created $<)

### Tracks
define exclude_empty=
$(foreach f,$(1), $(if $(call is_empty_file,$(f)),,$(f)))
endef

define stage3_tracks_targets=
$(subst .tsv,.tsv.tracks,$(call exclude_empty,$(STAGE3_TSV_FILES)))
endef

stage3_tracks: $(call stage3_tracks_targets)
	$(call p_info,[DONE] Generated stage 3 tracks)

stage3_upload_tracks: $(subst .tracks,.tracks.uploaded,$(stage3_tracks_targets))
	$(call p_info,[DONE] Uploaded stage 3 tracks)

stage4_tracks_targets=$(subst .tsv,.tsv.tracks,$(STAGE4_OUT_FILES))

stage4_tracks: $(stage4_tracks_targets)
	$(call p_info,[DONE] Generated stage 4 tracks)

stage4_upload_tracks: $(subst .tracks,.tracks.uploaded,$(stage4_tracks_targets))
	$(call p_info,[DONE] Uploaded stage 4 tracks)


# target to generate some tracks
get_tracks: stage2_tracks stage3_tracks stage4_tracks 


###################################################
# 
#$(name)/report/all_options.txt:
#	( $(foreach v, $(call interesting_vars), $(v) = $($(v)))) ) > /dev/stdout

#define pprint_var
#
#echo "$(1) = $($(1))"
#
#endef
#define interesting_vars=
#$(filter-out %_sd %_rs $(se) $(pe),$(foreach v,$(.VARIABLES),$(if $(subst file,,$(#origin $(v))),,$(v) )))
#endef

###################################################
# Alternative targets (lightweight)
do_index: setup_dirs $(word 1,$(index_files))

# TODO: rename the BAM file and add the headers if necessary
do_mapping: $(mapper)_mapping

###################################################
phony_targets+= save_cache 
save_cache: 
	($(call list_cached_vars)) > $(cached_vars_file).tmp && mv $(cached_vars_file).tmp $(cached_vars_file)

###################################################
# FORCE the program to run even if files haven't changed
FORCE:

#PHONY: performance improvement. Tell MAKE that those targets don't generate any files. 
.PHONY:  $(phony_targets)
.SILENT: $(silent_targets)
# disable deletion of temporary files
.SECONDARY: $(precious_targets)
.PRECIOUS: $(precious_targets)
###################################################