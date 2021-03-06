#!/bin/sh
# command
# sh quasil_pv.sh -it tissue_pv -itc tc_pv -iaif aif_pv -o output -m mask -pvgm pvgm -pvwm pvwm

# deal with options

if [ -z $1 ]; then
    echo "Not enough parameters."
    exit 1
fi

until [ -z $1 ]; do
    case $1 in
    # Mandatory parameters
    -it) it_flag=1 it_file=$2 # input tissue file
        shift;;
    -itc) itc_flag=1 itc_file=$2 # input tag control difference file
        shift;;
    -iaif) iaif_flag=1 iaif_file=$2 # input AIF file
        shift;;
	-o) out_flag=1 out_dir=$2 # Output folder
	    shift;;
	-m) mask_flag=1 mask=$2 # mask file
	    shift;;
	-pvgm) pvgm_flag=1 pvgm=$2 # GM PVE map
        shift;;
    -pvwm) pvwm_flag=1 pvwm=$2 # WM PVE map
        shift;;

    # Optional parameters
    --kernal) kernel=$2 # kernel size of LR method
        shift;;
    --FA) FA=$2 # QUASAR Look-locker readout flip angle (degree)
        shift;;
    --tau) tau=$2
        shift;;
	*)  #Usage
	    echo "Error! Unrecognised option on command line: $1"
	    echo ""
	    exit 1;;
    esac
    shift
done

# Check mandatory parameters
if [ -z $it_flag ]; then
    echo "Tissue input file not specified"
    exit 1
fi

if [ -z $itc_flag ]; then
    echo "TC input file not specified"
    exit 1
fi

if [ -z $iaif_flag ]; then
    echo "AIF input file not specified"
    exit 1
fi

if [ -z $out_flag ]; then
    echo "Output directory not specified"
    exit 1
fi

if [ -z $mask_flag ]; then
    echo "Mask file not specified"
    exit 1
fi

if [ -z $pvgm_flag ]; then
    echo "GM PV map not specified"
    exit 1
fi

if [ -z $pvwm_flag ]; then
    echo "WM PV map not specified"
    exit 1
fi

# Check optional parameters
if [ -z $kernel ]; then
	kernel=5;
fi

if [ -z $FA ]; then
	FA=35.8;
fi

if [ -z $tau ]; then
	tau=0.64;
fi

if [ -z $t1 ]; then
    t1=0.68;
fi

# Start program timer
$start_timestamp=$SECONDS

# Total number of TIs
ntis_tc=78 # QUASAR sequence six phases
ntis_t=13 # Tissue curve only

# Constant directory names
mbased_fabber_uncorr="mbased_FABBER_uncorr"
mbased_fabber_LR_before="mbased_FABBER_LR_before"
mbased_fabber_LR_after="mbased_FABBER_LR_after"

mbased_basil_uncorr="mbased_BASIL_uncorr"
mbased_basil_LR_before="mbased_BASIL_LR_before"
mbased_basil_LR_after="mbased_BASIL_LR_after"

mfree_uncorr="mfree_uncorr"
mfree_LR_before="mfree_LR_before"
mfree_LR_after="mfree_LR_after"

mbased_fabber_svb="mbased_FABBER_svb"
mbased_basil_svb="mbased_BASIL_svb"

# Starting directory (absolute path)
start_dir=`pwd`

# Procedures
echo "Begin partial volume correction on QUASAR ASL perfurion estimation"

mkdir $out_dir
cd $out_dir

# Output directory (absolute path)
out_dir=`pwd`

# Copy input files to output directory
imcp $start_dir/$it_file $out_dir/$it_file
imcp $start_dir/$itc_file $out_dir/$itc_file
imcp $start_dir/$iaif_file $out_dir/$iaif_file
imcp $start_dir/$mask $out_dir/$mask
imcp $start_dir/$pvgm $out_dir/$pvgm
imcp $start_dir/$pvwm $out_dir/$pvwm

#echo $out_dir/$it_file

it_file=$out_dir"/"$it_file
itc_file=$out_dir"/"$itc_file
iaif_file=$out_dir"/"$iaif_file
mask=$out_dir"/"$mask
pvgm=$out_dir"/"$pvgm
pvwm=$out_dir"/"$pvwm

# Copy option files to output directory
cp $start_dir/options_fabber.txt $out_dir/options_fabber.txt
cp $start_dir/options_basil.txt $out_dir/options_basil.txt
cp $start_dir/options_fabber_pv.txt $out_dir/options_fabber_pv.txt
cp $start_dir/options_basil_pv.txt $out_dir/options_basil_pv.txt

# Make GM WM masks
gm_mask="gm_mask"
wm_mask="wm_mask"
gm_mask=$out_dir"/"$gm_mask
wm_mask=$out_dir"/"$wm_mask
fslmaths $pvgm -bin $gm_mask
fslmaths $pvwm -bin $wm_mask

# Make eight output directories
mkdir $mbased_fabber_uncorr
mkdir $mbased_fabber_LR_before
mkdir $mbased_fabber_LR_after

mkdir $mbased_basil_uncorr
mkdir $mbased_basil_LR_before
mkdir $mbased_basil_LR_after

mkdir $mfree_uncorr
mkdir $mfree_LR_before
mkdir $mfree_LR_after

mkdir $mbased_fabber_svb
mkdir $mbased_basil_svb

# Split files for LR PV correction
cd $out_dir

# Calibration
calibrate_gm=" -div 1 -div 0.91 -mul 6000 -mas $gm_mask"

# Start CBF estimation
# Model-based analysis in FABBER
echo ""
echo "Begin model-based analysis in FABBER"

# No PV correction
echo ""
echo "Estimate CBF without PV correction..."

cd $mbased_fabber_uncorr

fabber --data=$itc_file --data-order=singlefile --mask=$mask --output=full -@ $out_dir/options_fabber.txt

# calibrate_gm using M0a_gm and apply GM mask
fslmaths full_latest/mean_ftiss $calibrate_gm perfusion_gm_mask

cd $out_dir


# LR PV correction on ASL data
echo ""
echo "Estimate CBF with PV correction on ASL data..."

cd $mbased_fabber_LR_before

corr_tc_gm_file="tc_pv_gm"

asl_file --data=$itc_file --ntis=$ntis_tc --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=$corr_tc_gm_file

# Estimate CBF
fabber --data=$corr_tc_gm_file --data-order=singlefile --mask=$mask --output=full -@ $out_dir/options_fabber.txt

# calibrate_gm
fslmaths full_latest/mean_ftiss $calibrate_gm perfusion_gm_mask

cd $out_dir


# LR PV correction on perfusion map
echo ""
echo "Estimate CBF with PV correction on perfusion map..."

cd $mbased_fabber_LR_after

# Estimate CBF
fabber --data=$itc_file --data-order=singlefile --mask=$mask --output=full -@ $out_dir/options_fabber.txt

# PV correction on perfusion map
#asl_pv_lr --data=full_latest/mean_ftiss --pv=$pvgm --mask=$mask --out=mean_ftiss_gm --kernel=$kernel

asl_file --data=full_latest/mean_ftiss --ntis=1 --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=mean_ftiss_gm

# calibrate_gm using M0a_gm and apply GM mask
fslmaths mean_ftiss_gm $calibrate_gm perfusion_gm_mask

cd $out_dir



# Model-based analysis in BASIL
echo ""
echo "Begin model-based analysis in BASIL"

# No PV correction
echo ""
echo "Estimate CBF without PV correction..."

cd $mbased_basil_uncorr

# Estimate CBF
basil -i $it_file -m $mask -o full -@ $out_dir/options_basil.txt

# calibrate_gm using M0a_gm and apply GM mask
fslmaths full/step1/mean_ftiss $calibrate_gm perfusion_gm_mask

cd $out_dir

# LR PV correction on ASL data
echo ""
echo "Estimate CBF with PV correction on ASL data..."

cd $mbased_basil_LR_before

corr_t_gm_file="tissue_pv_gm"

asl_file --data=$it_file --ntis=$ntis_t --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=$corr_t_gm_file

# Estimate CBF
basil -i $corr_t_gm_file -m $mask -o full -@ $out_dir/options_basil.txt

# calibrate_gm
fslmaths full/step1/mean_ftiss $calibrate_gm perfusion_gm_mask

cd $out_dir

# LR PV correction on perfusion map
echo ""
echo "Estimate CBF with PV correction on perfusion map..."

cd $mbased_basil_LR_after

# Estimate CBF
basil -i $it_file -m $mask -o full -@ $out_dir/options_basil.txt

# PV correction on perfusion map
#asl_pv_lr --data=full/step1/mean_ftiss --pv=$pvgm --mask=$mask --out=mean_ftiss_gm --kernel=$kernel

asl_file --data=full/step1/mean_ftiss --ntis=1 --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=mean_ftiss_gm

# calibrate_gm using M0a_gm and apply GM mask
fslmaths mean_ftiss_gm $calibrate_gm perfusion_gm_mask

cd $out_dir


# Model-free analysis
echo ""
echo "Begin model-free analysis"

# No PV correction
echo ""
echo "Estimate CBF without PV correction..."

cd $mfree_uncorr

# Estimate CBF
# Edit T1 value (which is not 1.6)
asl_mfree --data=$it_file --mask=$mask --aif=$iaif_file --dt=0.3 --t1=$t1 --out=full --fa=$FA

# calibrate_gm using M0a_gm and apply GM mask
fslmaths full_magntiude $calibrate_gm perfusion_gm_mask

cd $out_dir

# LR PV correction on ASL data
echo ""
echo "Estimate CBF with PV correction on ASL data..."

cd $mfree_LR_before

corr_aif_gm_file="aif_pv_gm"

asl_file --data=$iaif_file --ntis=$ntis_t --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=$corr_aif_gm_file


corr_t_gm_file="tissue_pv_gm"

asl_file --data=$it_file --ntis=$ntis_t --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=$corr_t_gm_file

# Estimate CBF
# Edit T1 value (which is not 1.6)
asl_mfree --data=$corr_t_gm_file --mask=$mask --aif=$corr_aif_gm_file --dt=0.3 --t1=$t1 --out=full --fa=$FA

# calibrate_gm using M0a_gm and apply GM mask
fslmaths full_magntiude $calibrate_gm perfusion_gm_mask


cd $out_dir

# LR PV correction on perfusion map
echo ""
echo "Estimate CBF with PV correction on perfuion map..."

cd $mfree_LR_after

# Estimate CBF
# Edit T1 value (which is not 1.6)
asl_mfree --data=$it_file --mask=$mask --aif=$iaif_file --dt=0.3 --t1=$t1 --out=full --fa=$FA

# PV correction on perfusion map
#asl_pv_lr --data=full_magntiude --pv=$pvgm --mask=$mask --out=full_magntiude_gm --kernel=$kernel

asl_file --data=full_magntiude --ntis=1 --pvmap=$pvgm --mask=$mask --kernel=$kernel --out=full_magntiude_gm

# calibrate_gm using M0a_gm and apply GM mask
fslmaths full_magntiude_gm $calibrate_gm perfusion_gm_mask


cd $out_dir


# Spatial Variational Bayes (svb) PV correction on QUASAR ASL differnt data
echo ""
echo "Estimate CBF with PV correction on QUASAR ASL different data by Spatial Variational Bayes (SVB)..."

cd $mbased_fabber_svb

# Estimate CBF
fabber --data=$itc_file --data-order=singlefile --mask=$mask --output=full -@ $out_dir/options_fabber_pv.txt

# Calibration
fslmaths full_latest/mean_ftiss $calibrate_gm perfusion_gm_mask

cd $out_dir



# Spatial Variational Bayes (svb) PV correction on QUASAR ASL differnt data
echo ""
echo "Estimate CBF with PV correction on QUASAR ASL tissue data by Spatial Variational Bayes (SVB)..."

cd $mbased_basil_svb

# Estimate CBF
basil -i $it_file -o full -m $mask --pgm $pvgm --pwm $pvwm -@ $out_dir/options_basil_pv.txt

# Calibration
fslmaths full/step2/mean_ftiss $calibrate_gm perfusion_gm_mask

cd $out_dir

echo ""
echo "All process completed!!"

end_timestamp=$SECONDS

echo "Duration: " $(((end_timestamp-start_timestamp)/60)) " minutes"




