#Kyle R Kovach
#SpectralPredictR
#December 1, 2020
#
# Fork used for Mill Test 2024 (github.com/krkovach/SpectralPredictR).
# Adapted 2026-09-11 to run non-interactively off data_root: both
# `choose.dir()` picker calls (Windows-only -- not exported by `utils` on
# Mac/Linux, confirmed by trying it here) replaced with paths/env vars.
# Logic below is otherwise as committed 2026-09-08 (commit fbff7ec).
#
# 2026-09-11: confirmed the study's actual analysis uses the upstream custom
# jump-correction method (jump_correct_specdal/apply_jump_correction below,
# from github.com/krkovach/SpectralPredictR main branch), not the
# spectrolab::match_sensors() call this script previously had -- swapped in.
# meta_cols is parameterized (upstream hardcodes 3; our pipeline carries only
# 1 meta column -- sample_name -- by this point, folder/format having been
# dropped earlier). Wavelength-name parsing also strips a leading non-digit
# prefix: this pipeline's column names come out "X350" etc. (R mangles
# pure-numeral data.frame names), not the bare "350" upstream assumes.

#----Load Libraries----
# install.packages("doParallel")
# install.packages("spectrolab")
# install.packages("dplyr")
# install.packages("tidyr")

require(doParallel)
require(spectrolab)
require(dplyr)
require(tidyr)

#----Jump Correction (github.com/krkovach/SpectralPredictR, main branch)----
jump_correct_specdal = function(spec_df, splices, reference=2, method="additive") {
  corrected = spec_df
  for (row_idx in seq_len(nrow(spec_df))) {
    series = as.numeric(spec_df[row_idx, ])
    names(series) = colnames(spec_df)
    wavelengths = as.numeric(gsub("^[^0-9]*", "", names(series)))
    if (any(is.na(wavelengths))) stop("Non-numeric column names in spectra.")
    get_sequence_num = function(w) {
      for (i in seq_along(splices)) if (w <= splices[i]) return(i)
      return(length(splices) + 1)
    }
    groups = split(series, sapply(wavelengths, get_sequence_num))
    translate_y = function(ref, mov, right=TRUE) {
      if (method == "additive") {
        diff = if (right) ref[length(ref)] - mov[1] else ref[1] - mov[length(mov)]
        return(mov + diff)
      } else if (method == "multiplicative") {
        ratio = if (right) ref[length(ref)] / mov[1] else ref[1] / mov[length(mov)]
        return(mov * ratio)
      } else {
        stop("Unknown method.")
      }
    }
    for (i in reference:(length(groups) - 1)) {
      groups[[i + 1]] = translate_y(groups[[i]], groups[[i + 1]], TRUE)
    }
    for (i in seq(reference, 2, by = -1)) {
      groups[[i - 1]] = translate_y(groups[[i]], groups[[i - 1]], FALSE)
    }
    corrected[row_idx, ] = unlist(groups)
  }
  corrected
}

apply_jump_correction = function(spec, instrument, splices=NULL, method="additive", meta_cols=3) {
  instrument = tolower(instrument)
  if (is.null(splices)) {
    if (instrument == "asd") splices = c(1000, 1800)
    if (instrument == "sig") splices = c(990, 1900)
  }
  message(sprintf("%s: %s jump correction.", toupper(instrument), method))
  spec_df = as.data.frame(spec)
  meta = spec_df[, seq_len(meta_cols), drop=FALSE]
  spectra = spec_df[, -seq_len(meta_cols), drop=FALSE]
  corrected = jump_correct_specdal(
    spectra,
    splices=splices,
    reference=2,
    method=method
  )
  cbind(meta, corrected)
}

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "spectralpredictr")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

#----Initialize----
set.seed(112345)
cores=detectCores()-1

# Folder of raw .asd/.sed/.sig files, searched recursively. Was an
# interactive choose.dir() picker; now points at the raw dry-spectra tree.
specfolder <- Sys.getenv("MILL24_SPEC_FOLDER", unset = file.path(data_root, "DrySpec"))

split_path=function(path) {
  if (dirname(path) %in% c("_", path)) return(basename(path))
  return(c(basename(path),split_path(dirname(path))))
}

# FFO accumulates the jump-corrected spectra across file formats via rbind()
# inside the loop below. Clear it first: if this script is re-run in a session
# that already ran it (e.g. line by line in RStudio), a leftover FFO from the
# previous run is silently appended to, and every spectrum is written twice.
if (exists('FFO')){rm(FFO)}

for (j in c("asd","sed","sig"))
{
  if (exists('finaloutput')){rm(finaloutput)}
  folderlist=unique(sub("/[^/]+$","",list.files(path=specfolder,
                                                pattern=paste0(".",j,"$"),
                                                recursive=TRUE,
                                                full.names = TRUE)))
  if (length(folderlist)!=0){
    cl=makeCluster(cores)
    registerDoParallel(cl)
    
    finaloutput=foreach(i=folderlist,
                        .combine=rbind,
                        .packages=c('spectrolab'))%dopar%
      {
        spectra=read_spectra(path=i,format=j)
        data.frame(spectra,folder=i,format=j,check.names=FALSE)
        }

    # 2026-09-11: some samples were scanned more than once, under
    # different dated session folders (e.g. 20250214_<operator> vs.
    # 20250313_<operator>), with materially different resulting spectra --
    # not byte-identical re-copies. Keeping the later-dated scan for now
    # (provisional -- no log says which scan was intended; the later
    # date is assumed correct). Folder-name dates parsed from the leading YYYYMMDD.
    dup_ids = unique(finaloutput$sample_name[duplicated(finaloutput$sample_name)])
    if (length(dup_ids) > 0) {
      folder_date = as.Date(sub(".*/(\\d{8})_[^/]+$", "\\1", finaloutput$folder), format="%Y%m%d")
      finaloutput = finaloutput[order(finaloutput$sample_name, folder_date), ]
      finaloutput = finaloutput[!duplicated(finaloutput$sample_name, fromLast=TRUE), ]
      finaloutput = finaloutput[order(finaloutput$sample_name), ]
      message(sprintf("%s: dropped earlier-dated duplicate scan(s) for %d sample(s): %s",
                       j, length(dup_ids), paste(dup_ids, collapse=", ")))
    }

    FST=as_spectra(finaloutput[,1:2152],name_idx=1)

    stopCluster(cl)

    FSTdf_pre=data.frame(FST,check.names=FALSE)
    if (j=="asd"){
      FSTdf=apply_jump_correction(FSTdf_pre, instrument="ASD", meta_cols=1)
    } else if (j=="sig"){
      FSTdf=apply_jump_correction(FSTdf_pre, instrument="SVC", meta_cols=1)
    } else {
      FSTdf=FSTdf_pre
    }
    if (!exists('FFO')){FFO=FSTdf[0,]}
    FFO=rbind(FFO,FSTdf)
  }};FSTfinal=as_spectra(FFO,name_idx=1);FSTfinal_norm=normalize(FSTfinal)

FST_f=data.frame(FSTfinal)
FST_n=data.frame(FSTfinal_norm)

# Sample names are the key every downstream script joins on; fail here rather
# than write a file that TraitSpectralQC.R (or worse, a silent join) trips on.
stopifnot("duplicate sample_name in combined spectra -- FFO was not reset, or a
           sample exists under more than one file format" =
            !any(duplicated(FST_f$sample_name)))

write.csv(FST_f,file.path(out_dir,"SpectralPredictR_raw_spectra.csv"),row.names=FALSE)
# FLAG (2026-09-11): FST_n (spectrolab::normalize() output) is written here
# but never read again -- the vector-normalization actually used below
# (`sampledata_VN`) is a separate hand-rolled calc over FST_f (raw, not
# FST_n). This matches the upstream script exactly, so it's not a change
# introduced here, but the filename implies this file feeds forward when it
# doesn't. Flagging rather than removing since it's an existing output name
# other scripts/README may expect.
write.csv(FST_n,file.path(out_dir,"SpectralPredictR_VN_jumpcorrected_spectra.csv"),row.names=FALSE)

#----Process Spectra, Vector Normalize, and Resample----
## This assumes all metadata exists only as the left side columns, and that the spectral dataset is consistant and ends the columns.
headcount=ncol(FST_f)-2151
specstart=headcount+1

cl=makeCluster(cores);registerDoParallel(cl);sampledata_VN=foreach(i=1:nrow(FST_f),
                                                                   .combine=rbind)%dopar%
  {
    a=FST_f[i,]
    b=sqrt(rowSums(a[,specstart:ncol(a)]^2))
    d=a[,-c(1:headcount)]
    sample_name=a[,c(1:headcount)]
    f=d/b
    cbind(sample_name,f)
  }
stopCluster(cl)

sampledata=sampledata_VN

sampledata_wav=sampledata[,-c(1:headcount)]
sampledata_head=sampledata[,c(1:headcount)]
sampledata_5nm_wav=sampledata_wav[,seq_len(ncol(sampledata_wav)) %% 5 == 1]
sampledata_5nm=cbind(sampledata_head,sampledata_5nm_wav)
sampledata=sampledata_5nm
write.csv(sampledata,file.path(out_dir,"SpectralPredictR_5nmresampled_spectra.csv"),row.names=FALSE)

#----Predict Traits----
# PLSR coefficient models (Wang et al. 2020), staged locally
# 2026-09-11 from https://ecosml.org/package/github/EnSpec/NEON-Trait-Models
# (NEON-Trait-Models-1.0_EcoSis_Version release) -- was an interactive
# choose.dir() picker.
trait_model_dir <- Sys.getenv(
  "MILL24_TRAIT_MODEL_DIR",
  unset = "/Volumes/Enspec/library/traits/Townsend_FoliarTraitModels/trait_models/NEON-Trait-Models-1.0_EcoSis_Version/NEON_dry_trait_model"
)
modeldirectory=list.files(path=trait_model_dir,
                          pattern=".csv$",
                          recursive=FALSE,
                          full.names = TRUE)

cl=makeCluster(cores);registerDoParallel(cl);finished_output=foreach(model=modeldirectory,
                                                                     .combine=rbind)%dopar%
  {
    modelname=split_path(model)[1]
    modelcoeffs_mat=data.matrix(read.csv(model, header = TRUE, row.names = 1,sep = ","))
    sampledata_tail=sampledata[,-c(1:headcount)]
    sampledata_head=sampledata[,c(1:headcount)]
    sampledata_tail$constant=1
    sampledata_tail=cbind(intercept=sampledata_tail[,ncol(sampledata_tail)],sampledata_tail[,c(1:ncol(sampledata_tail)-1)])
    sampledata_tail_mat=as.matrix(sampledata_tail)
    modeloutput=sampledata_tail_mat %*% t(modelcoeffs_mat)
    modeloutput_bind=cbind(sampledata_head,as.data.frame(modeloutput))
    data.frame(modelname=modelname,
               sampledata_head,
               t_mean=rowMeans(modeloutput),
               t_std=apply(modeloutput,1,sd),
               as.data.frame(modeloutput),
               check.names=FALSE)
  };stopCluster(cl)
predsub=finished_output#[,c(1:2,5:7,10:11)]
predspread=pivot_wider(data=predsub,id_cols=c(sampledata_head),names_from=modelname,values_from=c("t_mean","t_std"))
predunlist=as.data.frame(unnest(predspread))
colnames(predunlist)=sub(".csv", "", colnames(predunlist))
write.csv(predunlist,file.path(out_dir,"DimensionsDryTraitPredictions.csv"),row.names=FALSE)
