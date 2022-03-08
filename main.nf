#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/cellranger
========================================================================================
    Github : https://github.com/qbic-pipelines/cellranger
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/


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
if (params.cellranger_mode == 'gex') {
    include { CELLRANGER_GEX } from './workflows/cellranger'
else if (params.cellranger_mode == 'multi') {
    include { CELLRANGER_MULTI_WF } from './workflows/cellranger_multi'
}
//
// WORKFLOW: Run main qbic-pipelines/cellranger analysis pipeline
//
workflow {
    if (params.cellranger_mode == 'gex') {
        CELLRANGER_GEX ()
    } else if (params.cellranger_mode == 'multi') {
        CELLRANGER_MULTI_WF()
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
