library(biomaRt)
library(dplyr)
library(stringr)

ensembl_db_name <- function(specie) {
    if (specie == 'Canis_familiaris') {
        return("clfamiliaris_gene_ensembl")
    }
    suffix <- '_gene_ensembl'
    if (specie %in% c("Arabidopsis_thaliana", "Arabidopsis_lyrata")) {
        suffix <- '_eg_gene'
    }
    concat_ln <- function(two_part_str) {
        stringr::str_c(
            substr(two_part_str[1], 1, 1),
            two_part_str[2],
            suffix
        )
    }
    return(
        specie %>% tolower() %>% stringr::str_split('_') %>% unlist %>% concat_ln
    )
}

get_mart <- function(species) {
    if (species %in% c("Arabidopsis_thaliana", "Arabidopsis_lyrata")) {
        return(
            useEnsemblGenomes(biomart = "plants_mart", dataset = ensembl_db_name(species))
        )
    } else {
        return(
            useEnsembl(biomart = "ensembl", dataset = ensembl_db_name(species),  mirror = "useast")
        )
    }
    
}

if (exists("snakemake")) {
    motif_df <- read.csv(snakemake@input[["motif_table"]]) %>% dplyr::filter(source == "Ensembl")
    out_dir <- snakemake@output[[1]]
    logfile <- file(snakemake@log[[1]])
} else {
    motif_df <- read.csv("data/motif_pwm_df.csv") %>% dplyr::filter(source == "Ensembl")
    out_dir <- "output/ensembl_sequences"
    logfile <- file("logs/ensembl_download.log")
}
if (! dir.exists(out_dir)) {
    dir.create(out_dir)
}
pb <- txtProgressBar(
    min = 0,
    max = length(unique(motif_df$species)),
    initial=0
)
progress = 0
for (specie in unique(motif_df$species)) {
    mart <- get_mart(specie)
    # TODO: ensembl_gene_id fails for yeast
    seq <- tryCatch( {
        biomaRt::getSequence(
            id = subset(motif_df, species == specie)$gene_id, 
            type = "ensembl_gene_id", 
            seqType = "peptide", 
            mart = mart
        )
    }, error = function(cond) {
        return(NULL)
    })
    if (length(seq) > 0) {
        biomaRt::exportFASTA(
            seq,
            file.path(out_dir, stringr::str_c(specie, ".fa"))
        )
    } else {
        writeLines(stringr::str_c("failed with ", specie), logfile)
    }
    progress <- progress + 1
    setTxtProgressBar(pb, progress)
}
close(pb)
close(logfile)
