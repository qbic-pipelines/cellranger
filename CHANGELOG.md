# qbic-pipelines/cellranger: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## v2.0dev -

* Ported pipeline to Nextflow DSL2.

### `Added`

* Bump versions 2.0.
* `cellranger_mode` parameter, allows to select the cellranger operation mode: `GEX` or `multi` are supported.

### `Fixed`

* Fixed channel issues when not providing a reference file.

### `Dependencies`

* Updated GRCh38 cellranger GEX reference

### `Deprecated`

* `index_file` parameter is deprecated as it is no longer needed.
## v1.0.1 - Mordor - patch

### `Added`

* Using stub feature for CI tests.

### `Fixed`

* Fixed channel issues when not providing a reference file.

### `Dependencies`

### `Deprecated`

## v1.0 - Mordor

Initial release of qbic-pipelines/cellranger, created with the [nf-core](https://nf-co.re/) template.
