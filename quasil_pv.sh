#!/bin/sh


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
	FA=35;
fi

if [ -z $tau ]; then
	tau=0.64;
fi

# Total number of TIs
ntis_tc=78 # QUASAR sequence six phases
ntis_t=13 # Tissue curve only

#echo $it_file
#echo $itc_file
#echo $iaif_file
#echo $out_dir
#echo $mask
#echo $pvgm
#echo $pvwm
#echo $kernel
#echo $FA

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

# Copy option files to output directory
cp $start_dir/options_fabber.txt $out_dir/options_fabber.txt
cp $start_dir/options_basil.txt $out_dir/options_basil.txt

# Make GM WM masks
gm_mask="gm_mask"
wm_mask="wm_mask"
fslmaths $out_dir/$pvgm -bin $out_dir/$gm_mask
fslmaths $out_dir/$pvwm -bin $out_dir/$wm_mask

# Make six output directories
mkdir $mbased_fabber_uncorr
mkdir $mbased_fabber_LR_before
mkdir $mbased_fabber_LR_after

mkdir $mbased_basil_uncorr
mkdir $mbased_basil_LR_before
mkdir $mbased_basil_LR_after

mkdir $mfree_uncorr
mkdir $mfree_LR_before
mkdir $mfree_LR_after

# Get absolute directory path
#mbased_fabber_uncorr=$out_dir/$mbased_fabber_uncorr
#mbased_fabber_LR_before=$out_dir/$mbased_fabber_LR_before
#mbased_fabber_LR_after=$out_dir/$mbased_fabber_LR_after

#mbased_basil_uncorr=$out_dir/$mbased_basil_uncorr
#mbased_basil_LR_before=$out_dir/$mbased_basil_LR_before
#mbased_basil_LR_after=$out_dir/$mbased_basil_LR_after

#mfree_uncorr=$out_dir/$mfree_uncorr
#mfree_LR_before=$out_dir/$mfree_LR_before
#mfree_LR_after=$out_dir/$mfree_LR_after

# Split files for LR PV correction
cd $out_dir

# Split AIF
asl_file --data=$it_file --ntis=$ntis_t --split=aif_ti_

# Split Tissue
asl_file --data=$iaif_file --ntis=$ntis_t --split=tissue_ti_

# Split TC difference
asl_file --data=$itc_file --ntis=$ntis_tc --split=tc_ti_

# Start CBF estimation
# Model-based analysis in FABBER
echo ""
echo "Begin model-based analysis in FABBER"

# No PV correction
echo ""
echo "Estimate CBF without PV correction..."

cd $mbased_fabber_uncorr

fabber --data=$out_dir/$itc_file --data-order=singlefile --mask=$out_dir/$mask --output=full -@ $out_dir/options_fabber.txt

#fslmaths full_latest/mean_ftiss $scale_uncorr perfusion_gm_mask

cd $out_dir

# LR PV correction on ASL data
echo ""
echo "Estimate CBF with PV correction on ASL data..."

cd $mbased_fabber_LR_before


cd $out_dir

# LR PV correction on perfusion map
echo ""
echo "Estimate CBF with PV correction on perfusion map..."

cd $mbased_fabber_LR_after

# Estimate CBF
fabber --data=$out_dir/$itc_file --data-order=singlefile --mask=$out_dir/$mask --output=full -@ $out_dir/options_fabber.txt

# PV correction on perfusion map
asl_pv_lr --data=full_latest/mean_ftiss --pvgm=$pvgm --pvwm=$pvwm --mask=$mask --out=not_used --kernel=$kernel

calibrate=" -div 1 -div 0.91 "
# Calibrate using M0a_gm and apply GM mask
fslmaths mean_ftiss_gm $calibrate -mul 6000 -mas gm_mask perfusion_gm_mask

cd $out_dir



# Model-based analysis in BASIL
echo ""
echo "Begin model-based analysis in BASIL"

# No PV correction
echo ""
echo "Estimate CBF without PV correction..."

cd $mbased_basil_uncorr

basil -i $out_dir/$it_file -m $out_dir/$mask -o full -@ $out_dir/options_basil.txt

cd $out_dir

# LR PV correction on ASL data
echo ""
echo "Estimate CBF with PV correction on ASL data..."

cd $mbased_basil_LR_before


cd $out_dir

# LR PV correction on perfusion map
echo ""
echo "Estimate CBF with PV correction on perfusion map..."

cd $mbased_basil_LR_after

# Estimate CBF
basil -i $out_dir/$it_file -m $out_dir/$mask -o full -@ $out_dir/options_basil.txt

# PV correction on perfusion map

cd $out_dir


# Model-free analysis
echo ""
echo "Begin model-free analysis"

# No PV correction
echo ""
echo "Estimate CBF without PV correction..."

cd $mfree_uncorr

# Edit T1 value (which is not 1.6)
asl_mfree --data=$out_dir/$it_file --mask=$out_dir/$mask --aif=$out_dir/$iaif_file --dt=0.3 --t1=1.6 --out=full --fa=$FA

cd $out_dir

# LR PV correction on ASL data
echo ""
echo "Estimate CBF with PV correction on ASL data..."

cd $mfree_LR_before


cd $out_dir

# LR PV correction on perfusion map
echo ""
echo "Estimate CBF with PV correction on perfuion map..."

cd $mfree_LR_after

# Estimate CBF
# Edit T1 value (which is not 1.6)
asl_mfree --data=$out_dir/$it_file --mask=$out_dir/$mask --aif=$out_dir/$iaif_file --dt=0.3 --t1=1.6 --out=full --fa=$FA

# PV correction on perfusion map

cd $out_dir


echo ""
echo "All process completed!!"
