#!/usr/bin/env python3
# Generates cellranger multi config file from inputs
import argparse
import os

parser = argparse.ArgumentParser()
parser.add_argument("-s", "--samples", type=str, help="List of sample names.")
parser.add_argument("-ft", "--feature_types", type=str, help="List of sample names.")
parser.add_argument("-sd", "--sample_dirs", type=str, help="List of sample directory names.")
parser.add_argument("-gexr", "--gex_reference", type=str, help="Name of GEX reference.")
parser.add_argument("-vdjr", "--vdj_reference", type=str, help="Name of VDJ reference.")
parser.add_argument("-fbr", "--fb_reference", type=str, help="Name of Feature Barcode reference.")
parser.add_argument("-o", "--output_name", type=str, help="Name of output config file.")

args = parser.parse_args()

# Read and transform arguments to list
print(args.samples)
samples = args.samples.strip('[').strip(']').replace(" ","")
print(samples)
samples_list = samples.split(',')
print(samples_list)
samples_list = [ x.replace("|",",") for x in samples_list]
feature_types = args.feature_types.strip('[').strip(']').replace(" ","")
feature_type_list = feature_types.split(',')
print(feature_type_list)
sample_dirs = args.sample_dirs.strip('[').strip(']').replace(" ","")
sample_dirs_list = sample_dirs.split(',')
print(samples_list)
outname = args.output_name

# Get current path
path = os.getcwd()
print(path)

keys = ['gex', 'fb', 'vdj_b', 'vdj_t']
vals = ['gene expression','antibody capture','vdj-b','vdj-t']
dict_ft = dict(zip(keys,vals))

gex_reference = args.gex_reference
vdj_reference = args.vdj_reference
fb_reference = args.fb_reference
print(vdj_reference)
print(gex_reference)
print(fb_reference)

with open(outname, 'w') as f:
    f.write("[gene-expression]\n")
    f.write("reference,{0}/{1}\n".format(path,gex_reference))
    f.write("[vdj]\n")
    f.write("reference,{0}/{1}\n".format(path,vdj_reference))
    f.write("[feature]\n")
    f.write("reference,{0}/{1}\n".format(path,fb_reference))
    f.write("[libraries]\n")
    f.write("fastq_id,fastqs,feature_types\n")
    for (sample,dir,ft) in zip(samples_list,sample_dirs_list,feature_type_list):
        if "," in sample:
            f.write("\"{0}\",{1},{2}\n".format(sample,dir,dict_ft[ft]))
        else:
            f.write("{0},{1},{2}\n".format(sample,dir,dict_ft[ft]))




