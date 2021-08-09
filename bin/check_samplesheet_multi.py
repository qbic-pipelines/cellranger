#!/usr/bin/env python

import os
import sys
import errno
import argparse


def parse_args(args=None):
    Description = "Reformat nf-core/cellranger samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output featuretypes file.")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)


def check_samplesheet(file_in, file_out):
    """
    This function checks that the samplesheet follows the following structure:

    gem,fastq_id,fastqs,feature_types
    gem1,sc5p_v2_hs_PBMC_10k_5gex,/sfs/7/workspace/ws/qeaga01-GEX_TCR_BCR_FB-0/data/sc5p_v2_hs_PBMC_10k_5gex_5fb_fastqs/sc5p_v2_hs_PBMC_10k_5gex_fastqs,gene expression
    gem1,sc5p_v2_hs_PBMC_10k_5fb,/sfs/7/workspace/ws/qeaga01-GEX_TCR_BCR_FB-0/data/sc5p_v2_hs_PBMC_10k_5gex_5fb_fastqs/sc5p_v2_hs_PBMC_10k_5fb_fastqs,antibody capture
    gem1,sc5p_v2_hs_PBMC_10k_b,/sfs/7/workspace/ws/qeaga01-GEX_TCR_BCR_FB-0/data/sc5p_v2_hs_PBMC_10k_b_fastqs,vdj-b
    gem1,sc5p_v2_hs_PBMC_10k_t,/sfs/7/workspace/ws/qeaga01-GEX_TCR_BCR_FB-0/data/sc5p_v2_hs_PBMC_10k_t_fastqs,vdj-t
    """

    featuretype_list = list()
    sample_mapping_dict = {}
    with open(file_in, "r") as fin:

        ## Check header
        MIN_COLS = 4
        # TODO nf-core: Update the column names for the input samplesheet
        HEADER = ["gem", "fastq_id", "fastqs", "feature_types"]
        header = [x.strip('"') for x in fin.readline().strip().split(",")]
        if header[: len(HEADER)] != HEADER:
            print("ERROR: Please check samplesheet header -> {} != {}".format(",".join(header), ",".join(HEADER)))
            sys.exit(1)

        ## Check sample entries
        for line in fin:
            lspl = [x.strip().strip('"') for x in line.strip().split(",")]

            # Check valid number of columns per row
            if len(lspl) < len(HEADER):
                print_error(
                    "Invalid number of columns (minimum = {})!".format(len(HEADER)),
                    "Line",
                    line,
                )
            num_cols = len([x for x in lspl if x])
            if num_cols < MIN_COLS:
                print_error(
                    "Invalid number of populated columns (minimum = {})!".format(MIN_COLS),
                    "Line",
                    line,
                )

            ## Check sample name entries
            gem, fastq_id, fastqs, feature_types = lspl[: len(HEADER)]
            if not gem:
                print_error("gem entry has not been specified!", "Line", line)
            if not fastq_id:
                print_error("fastq_id entry has not been specified!", "Line", line)
            if not fastqs:
                print_error("fastqs entry has not been specified!", "Line", line)
            if not feature_types:
                print_error("feature_types entry has not been specified!", "Line", line)
            if feature_types not in ["gex", "fb", "vdj-b", "vdj-t"]:
                print_error("invalid feature type, should be gex, fb, vdj-b or vdj-t", "Line", line)

            ## Create list of feature types
            featuretype_list.append(feature_types)

            sample_info = [gem, fastqs, feature_types]
            ## Create sample mapping dictionary = { sample: [ single_end, fastq_1, fastq_2 ] }
            if fastq_id not in sample_mapping_dict:
                sample_mapping_dict[fastq_id] = [sample_info]
            else:
                if sample_info in sample_mapping_dict[fastq_id]:
                    print_error("Samplesheet contains duplicate rows!", "Line", line)
                else:
                    print_error("Samplesheet contains duplicate fastq_id entries!", "Line", line)

        # Checking featuretype list
        ftypes = ["gex", "fb", "vdj-b", "vdj-t"]
        featuretype_list = set(featuretype_list)
        exist = list()
        for ft in ftypes:
            if ft in featuretype_list:
                exist.append("1")
            else:
                exist.append("0")

        with open(file_out, "w") as fout:
            fout.write(",".join(ftypes)+"\n")
            fout.write(",".join(exist)+"\n")


def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)


if __name__ == "__main__":
    sys.exit(main())
