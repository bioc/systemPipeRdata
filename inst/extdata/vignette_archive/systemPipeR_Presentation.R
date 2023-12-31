## ----style, echo = FALSE, results = 'asis'-------------------------------
BiocStyle::markdown()
options(width=100, max.print=1000)
knitr::opts_chunk$set(
    eval=as.logical(Sys.getenv("KNITR_EVAL", "TRUE")),
    cache=as.logical(Sys.getenv("KNITR_CACHE", "TRUE")))

## ----setup, echo=FALSE, messages=FALSE, warnings=FALSE-------------------
suppressPackageStartupMessages({
    library(systemPipeR)
    library(systemPipeRdata)
    library(BiocParallel)
    library(Biostrings)
    library(Rsamtools)
    library(GenomicRanges)
    library(ggplot2)
    library(GenomicAlignments)
    library(ShortRead)
})

## ----update_teaching_material, eval=FALSE--------------------------------
## download.file("https://raw.githubusercontent.com/tgirke/systemPipeRdata/master/vignettes/systemPipeR_Presentation.Rmd", "systemPipeR_Presentation.Rmd", method="libcurl")
## download.file("https://raw.githubusercontent.com/tgirke/systemPipeRdata/master/vignettes/systemPipeR_Presentation.html", "systemPipeR_Presentation.html", method="libcurl")
## download.file("https://raw.githubusercontent.com/tgirke/systemPipeRdata/master/inst/extdata/workflows/varseq/systemPipeVARseq_single.Rnw", "systemPipeVARseq_single.Rnw", method="libcurl")
## download.file("https://github.com/tgirke/systemPipeRdata/raw/master/inst/extdata/workflows/varseq/systemPipeVARseq_single.pdf", "systemPipeVARseq_single.pdf", method="libcurl")

## ----install, eval=FALSE-------------------------------------------------
## if (!requireNamespace("BiocManager", quietly=TRUE))
    ## install.packages("BiocManager")
## BiocManager::install("systemPipeR") # Installs systemPipeR from Bioconductor
## BiocManager::install("tgirke/systemPipeRdata", build_vignettes=TRUE, dependencies=TRUE) # From github

## ----documentation, eval=FALSE-------------------------------------------
## library("systemPipeR") # Loads the package
## library(help="systemPipeR") # Lists package info
## vignette("systemPipeR") # Opens vignette

## ----genRna_workflow, eval=FALSE-----------------------------------------
## library(systemPipeRdata)
## genWorkenvir(workflow="rnaseq")
## setwd("rnaseq")

## ----targetsSE, eval=TRUE------------------------------------------------
library(systemPipeR)
read.delim("targets.txt", comment.char = "#")

## ----targetsPE, eval=TRUE------------------------------------------------
read.delim("targetsPE.txt", comment.char = "#")[1:2,1:6]

## ----comment_lines, eval=TRUE--------------------------------------------
readLines("targets.txt")[1:4]

## ----targetscomp, eval=TRUE----------------------------------------------
readComp(file="targets.txt", format="vector", delim="-")

## ----param_structure, eval=TRUE------------------------------------------
read.delim("param/tophat.param", comment.char = "#")

## ----param_import, eval=TRUE---------------------------------------------
args <- suppressWarnings(systemArgs(sysma="param/tophat.param", mytargets="targets.txt"))
args

## ----sysarg_access, eval=TRUE--------------------------------------------
names(args)
modules(args)
cores(args)
outpaths(args)[1]
sysargs(args)[1]

## ----load_package, eval=FALSE--------------------------------------------
## library(systemPipeR)

## ----construct_sysargs, eval=FALSE---------------------------------------
## args <- systemArgs(sysma="param/trim.param", mytargets="targets.txt")

## ----preprocessing, eval=FALSE-------------------------------------------
## preprocessReads(args=args, Fct="trimLRPatterns(Rpattern='GCCCGGGTAA', subject=fq)",
##                 batchsize=100000, overwrite=TRUE, compress=TRUE)
## writeTargetsout(x=args, file="targets_trim.txt")

## ----custom_preprocessing, eval=FALSE------------------------------------
## args <- systemArgs(sysma="param/trimPE.param", mytargets="targetsPE.txt")
## filterFct <- function(fq, cutoff=20, Nexceptions=0) {
##     qcount <- rowSums(as(quality(fq), "matrix") <= cutoff)
##     fq[qcount <= Nexceptions] # Retains reads where Phred scores are >= cutoff with N exceptions
## }
## preprocessReads(args=args, Fct="filterFct(fq, cutoff=20, Nexceptions=0)", batchsize=100000)
## writeTargetsout(x=args, file="targets_PEtrim.txt")

## ----fastq_quality, eval=FALSE-------------------------------------------
## fqlist <- seeFastq(fastq=infile1(args), batchsize=10000, klength=8)
## pdf("./results/fastqReport.pdf", height=18, width=4*length(fqlist))
## seeFastqPlot(fqlist)
## dev.off()

## ----fastq_quality_parallel_single, eval=FALSE---------------------------
## args <- systemArgs(sysma="param/tophat.param", mytargets="targets.txt")
## f <- function(x) seeFastq(fastq=infile1(args)[x], batchsize=100000, klength=8)
## fqlist <- bplapply(seq(along=args), f, BPPARAM = MulticoreParam(workers=8))
## seeFastqPlot(unlist(fqlist, recursive=FALSE))

## ----fastq_quality_parallel_cluster, eval=FALSE--------------------------
## library(BiocParallel); library(BatchJobs)
## f <- function(x) {
##     library(systemPipeR)
##     args <- systemArgs(sysma="param/tophat.param", mytargets="targets.txt")
##     seeFastq(fastq=infile1(args)[x], batchsize=100000, klength=8)
## }
## funs <- makeClusterFunctionsTorque("torque.tmpl")
## param <- BatchJobsParam(length(args), resources=list(walltime="20:00:00", nodes="1:ppn=1", memory="6gb"), cluster.functions=funs)
## register(param)
## fqlist <- bplapply(seq(along=args), f)
## seeFastqPlot(unlist(fqlist, recursive=FALSE))

## ----bowtie_index, eval=FALSE--------------------------------------------
## args <- systemArgs(sysma="param/tophat.param", mytargets="targets.txt")
## moduleload(modules(args)) # Skip if module system is not available
## system("bowtie2-build ./data/tair10.fasta ./data/tair10.fasta")

## ----run_bowtie_single, eval=FALSE---------------------------------------
## bampaths <- runCommandline(args=args)

## ----run_bowtie_parallel, eval=FALSE-------------------------------------
## resources <- list(walltime="20:00:00", nodes=paste0("1:ppn=", cores(args)), memory="10gb")
## reg <- clusterRun(args, conffile=".BatchJobs.R", template="torque.tmpl", Njobs=18, runid="01",
##                   resourceList=resources)
## waitForJobs(reg)

## ----process_monitoring, eval=FALSE--------------------------------------
## showStatus(reg)
## file.exists(outpaths(args))
## sapply(1:length(args), function(x) loadResult(reg, x)) # Works after job completion

## ----align_stats1, eval=FALSE--------------------------------------------
## read_statsDF <- alignStats(args)
## write.table(read_statsDF, "results/alignStats.xls", row.names=FALSE, quote=FALSE, sep="\t")

## ----align_stats2, eval=TRUE---------------------------------------------
read.table(system.file("extdata", "alignStats.xls", package="systemPipeR"), header=TRUE)[1:4,]

## ----align_stats_parallel, eval=FALSE------------------------------------
## f <- function(x) alignStats(args[x])
## read_statsList <- bplapply(seq(along=args), f, BPPARAM = MulticoreParam(workers=8))
## read_statsDF <- do.call("rbind", read_statsList)

## ----align_stats_parallel_cluster, eval=FALSE----------------------------
## library(BiocParallel); library(BatchJobs)
## f <- function(x) {
##     library(systemPipeR)
##     args <- systemArgs(sysma="tophat.param", mytargets="targets.txt")
##     alignStats(args[x])
## }
## funs <- makeClusterFunctionsTorque("torque.tmpl")
## param <- BatchJobsParam(length(args), resources=list(walltime="20:00:00", nodes="1:ppn=1", memory="6gb"), cluster.functions=funs)
## register(param)
## read_statsList <- bplapply(seq(along=args), f)
## read_statsDF <- do.call("rbind", read_statsList)

## ----igv, eval=FALSE-----------------------------------------------------
## symLink2bam(sysargs=args, htmldir=c("~/.html/", "somedir/"),
##             urlbase="http://myserver.edu/~username/",
##         urlfile="IGVurl.txt")

## ----bowtie2, eval=FALSE-------------------------------------------------
## args <- systemArgs(sysma="bowtieSE.param", mytargets="targets.txt")
## moduleload(modules(args)) # Skip if module system is not available
## bampaths <- runCommandline(args=args)

## ----bowtie2_cluster, eval=FALSE-----------------------------------------
## resources <- list(walltime="20:00:00", nodes=paste0("1:ppn=", cores(args)), memory="10gb")
## reg <- clusterRun(args, conffile=".BatchJobs.R", template="torque.tmpl", Njobs=18, runid="01",
##                   resourceList=resources)
## waitForJobs(reg)

## ----bwamem_cluster, eval=FALSE------------------------------------------
## args <- systemArgs(sysma="param/bwa.param", mytargets="targets.txt")
## moduleload(modules(args)) # Skip if module system is not available
## system("bwa index -a bwtsw ./data/tair10.fasta") # Indexes reference genome
## bampaths <- runCommandline(args=args[1:2])

## ----rsubread, eval=FALSE------------------------------------------------
## library(Rsubread)
## args <- systemArgs(sysma="param/rsubread.param", mytargets="targets.txt")
## buildindex(basename=reference(args), reference=reference(args)) # Build indexed reference genome
## align(index=reference(args), readfile1=infile1(args)[1:4], input_format="FASTQ",
##       output_file=outfile1(args)[1:4], output_format="SAM", nthreads=8, indels=1, TH1=2)
## for(i in seq(along=outfile1(args))) asBam(file=outfile1(args)[i], destination=gsub(".sam", "", outfile1(args)[i]), overwrite=TRUE, indexDestination=TRUE)

## ----gsnap, eval=FALSE---------------------------------------------------
## library(gmapR); library(BiocParallel); library(BatchJobs)
## args <- systemArgs(sysma="param/gsnap.param", mytargets="targetsPE.txt")
## gmapGenome <- GmapGenome(reference(args), directory="data", name="gmap_tair10chr/", create=TRUE)
## f <- function(x) {
##     library(gmapR); library(systemPipeR)
##     args <- systemArgs(sysma="gsnap.param", mytargets="targetsPE.txt")
##     gmapGenome <- GmapGenome(reference(args), directory="data", name="gmap_tair10chr/", create=FALSE)
##     p <- GsnapParam(genome=gmapGenome, unique_only=TRUE, molecule="DNA", max_mismatches=3)
##     o <- gsnap(input_a=infile1(args)[x], input_b=infile2(args)[x], params=p, output=outfile1(args)[x])
## }
## funs <- makeClusterFunctionsTorque("torque.tmpl")
## param <- BatchJobsParam(length(args), resources=list(walltime="20:00:00", nodes="1:ppn=1", memory="6gb"), cluster.functions=funs)
## register(param)
## d <- bplapply(seq(along=args), f)

## ----genVar_workflow_single, eval=FALSE----------------------------------
## setwd("../")
## genWorkenvir(workflow="varseq")
## setwd("varseq")

## ----sessionInfo---------------------------------------------------------
sessionInfo()

