#!/bin/bash
set -euxo pipefail
#################### SETUP ####################


human_genome="GRCh38"
mouse_genome="mm10"
version="2020-A"


build_human="GRCh38-2020-A_build"
build_mouse="mm10-2020-A_build"
mkdir -p "$build_human"
mkdir -p "$build_mouse"


# Download source files if they do not exist in reference_sources/ folder
source="reference_sources"
mkdir -p "$source"


human_fasta_url="http://ftp.ensembl.org/pub/release-98/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz"
human_fasta_in="${source}/Homo_sapiens.GRCh38.dna.primary_assembly.fa"
human_gtf_url="http://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_32/gencode.v32.primary_assembly.annotation.gtf.gz"
human_gtf_in="${source}/gencode.v32.primary_assembly.annotation.gtf"
mouse_fasta_url="http://ftp.ensembl.org/pub/release-98/fasta/mus_musculus/dna/Mus_musculus.GRCm38.dna.primary_assembly.fa.gz"
mouse_fasta_in="${source}/Mus_musculus.GRCm38.dna.primary_assembly.fa"
mouse_gtf_url="http://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M23/gencode.vM23.primary_assembly.annotation.gtf.gz"
mouse_gtf_in="${source}/gencode.vM23.primary_assembly.annotation.gtf"


if [ ! -f "$human_fasta_in" ]; then
    curl -sS "$human_fasta_url" | zcat > "$human_fasta_in"
fi
if [ ! -f "$human_gtf_in" ]; then
    curl -sS "$human_gtf_url" | zcat > "$human_gtf_in"
fi
if [ ! -f "$mouse_fasta_in" ]; then
    curl -sS "$mouse_fasta_url" | zcat > "$mouse_fasta_in"
fi
if [ ! -f "$mouse_gtf_in" ]; then
    curl -sS "$mouse_gtf_url" | zcat > "$mouse_gtf_in"
fi


# String patterns used for both genomes
ID="(ENS(MUS)?[GTE][0-9]+)\.([0-9]+)"


BIOTYPE_PATTERN=\
"(protein_coding|lncRNA|\
IG_C_gene|IG_D_gene|IG_J_gene|IG_LV_gene|IG_V_gene|\
IG_V_pseudogene|IG_J_pseudogene|IG_C_pseudogene|\
TR_C_gene|TR_D_gene|TR_J_gene|TR_V_gene|\
TR_V_pseudogene|TR_J_pseudogene)"
GENE_PATTERN="gene_type \"${BIOTYPE_PATTERN}\""
TX_PATTERN="transcript_type \"${BIOTYPE_PATTERN}\""
READTHROUGH_PATTERN="tag \"readthrough_transcript\""
PAR_PATTERN="tag \"PAR\""


#################### HUMAN ####################
# Please see the GRCh38-2020-A build documentation for details on these steps.


# Process FASTA -- translate chromosome names
human_fasta_modified="$build_human/$(basename "$human_fasta_in").modified"
cat "$human_fasta_in" \
    | sed -E 's/^>(\S+).*/>\1 \1/' \
    | sed -E 's/^>([0-9]+|[XY]) />chr\1 /' \
    | sed -E 's/^>MT />chrM /' \
    > "$human_fasta_modified"


# Process GTF -- split Ensembl IDs from version suffixes
human_gtf_modified="$build_human/$(basename "$human_gtf_in").modified"
cat "$human_gtf_in" \
    | sed -E 's/gene_id "'"$ID"'";/gene_id "\1"; gene_version "\3";/' \
    | sed -E 's/transcript_id "'"$ID"'";/transcript_id "\1"; transcript_version "\3";/' \
    | sed -E 's/exon_id "'"$ID"'";/exon_id "\1"; exon_version "\3";/' \
    > "$human_gtf_modified"


# Process GTF -- filter based on gene/transcript tags
cat "$human_gtf_modified" \
    | awk '$3 == "transcript"' \
    | grep -E "$GENE_PATTERN" \
    | grep -E "$TX_PATTERN" \
    | grep -Ev "$READTHROUGH_PATTERN" \
    | grep -Ev "$PAR_PATTERN" \
    | sed -E 's/.*(gene_id "[^"]+").*/\1/' \
    | sort \
    | uniq \
    > "${build_human}/gene_allowlist"


human_gtf_filtered="${build_human}/$(basename "$human_gtf_in").filtered"
grep -E "^#" "$human_gtf_modified" > "$human_gtf_filtered"
grep -Ff "${build_human}/gene_allowlist" "$human_gtf_modified" \
    >> "$human_gtf_filtered"


#################### MOUSE ####################
# Please see the mm10-2020-A build documentation for details on these steps.


# Process FASTA -- translate chromosome names
mouse_fasta_modified="$build_mouse/$(basename "$mouse_fasta_in").modified"
cat "$mouse_fasta_in" \
    | sed -E 's/^>(\S+).*/>\1 \1/' \
    | sed -E 's/^>([0-9]+|[XY]) />chr\1 /' \
    | sed -E 's/^>MT />chrM /' \
    > "$mouse_fasta_modified"


# Process GTF -- split Ensembl IDs from version suffixes
mouse_gtf_modified="$build_mouse/$(basename "$mouse_gtf_in").modified"
cat "$mouse_gtf_in" \
    | sed -E 's/gene_id "'"$ID"'";/gene_id "\1"; gene_version "\3";/' \
    | sed -E 's/transcript_id "'"$ID"'";/transcript_id "\1"; transcript_version "\3";/' \
    | sed -E 's/exon_id "'"$ID"'";/exon_id "\1"; exon_version "\3";/' \
    > "$mouse_gtf_modified"


# Process GTF -- filter based on gene/transcript tags
cat "$mouse_gtf_modified" \
    | awk '$3 == "transcript"' \
    | grep -E "$GENE_PATTERN" \
    | grep -E "$TX_PATTERN" \
    | grep -Ev "$READTHROUGH_PATTERN" \
    | sed -E 's/.*(gene_id "[^"]+").*/\1/' \
    | sort \
    | uniq \
    > "${build_mouse}/gene_allowlist"


mouse_gtf_filtered="${build_mouse}/$(basename "$mouse_gtf_in").filtered"
grep -E "^#" "$mouse_gtf_modified" > "$mouse_gtf_filtered"
grep -Ff "${build_mouse}/gene_allowlist" "$mouse_gtf_modified" \
    >> "$mouse_gtf_filtered"


#################### MKREF ####################


cellranger mkref --ref-version="$version" \
    --genome="$human_genome" --fasta="$human_fasta_modified" --genes="$human_gtf_filtered"

cellranger mkref --ref-version"$version" \
    --genome="$mouse_genome" --fasta="$mouse_fasta_modified" --genes="$mouse_gtf_filtered"
