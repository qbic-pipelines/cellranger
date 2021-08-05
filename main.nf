#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/cellranger
========================================================================================
    Github : https://github.com/nf-core/cellranger
    Website: https://nf-co.re/cellranger
    Slack  : https://nfcore.slack.com/channels/cellranger
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { CELLRANGER } from './workflows/cellranger'

//
// WORKFLOW: Run main nf-core/cellranger analysis pipeline
//
workflow NFCORE_CELLRANGER {
    CELLRANGER ()
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_CELLRANGER ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
