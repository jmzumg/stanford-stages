# Running stanford-stages in an XNAT Jupyter notebook

This image lets you run the sleep stage classifier from a Jupyter notebook inside
XNAT's JupyterHub integration. It follows the conventions of the other
`xnat-*-notebook` images (see
`xnat-jupyterhub-image/dockerfiles/xnat-datascience-notebook/`) and bundles
**everything** needed to score a recording - application code, scaling/noise
assets, and the large `ac/` LSTM models - so nothing has to be mounted or
downloaded at runtime.

## Why a separate kernel

The classifier is pinned to Python 3.7 (TensorFlow 2.5, numpy 1.19.5), which does
not coexist with the notebook base image's much newer Python. The image therefore
installs the classifier into a dedicated Python 3.7 conda environment and
registers it as a Jupyter kernel named **`Python 3.7 (stanford-stages)`**. The
JupyterLab UI runs on the base Python; your classifier code runs on the 3.7
kernel. Select it via *Kernel -> Change Kernel...* (or when creating a notebook).

## Building the image

Build from the repository root so the source and models are in the build context.
Fetch the models first (they are baked in, not mounted):

```sh
./get_assets.sh models      # populates ml/ac/  (~770 MiB)
docker build -f Dockerfile.xnat-notebook -t xnat/stanford-stages-notebook:latest .
```

The build uses `Dockerfile.xnat-notebook.dockerignore` (BuildKit prefers a
`<dockerfile>.dockerignore` over the root `.dockerignore`), which - unlike the
root ignore file - keeps `ml/` in the context so the models are bundled. The
resulting image is large (several GB) because the models are inside it.

Register the image with XNAT's JupyterHub plugin as you would any other
single-user notebook image.

## Running the classifier from Python

The image ships a ready-to-run notebook at
`/opt/stanford-stages/notebooks/stanford_stages_demo.ipynb` (also copied into the
home directory on launch). The essential steps:

1. Switch the kernel to **`Python 3.7 (stanford-stages)`**.

2. Import the package. A `.pth` file baked into the environment puts the module
   directory on `sys.path`, so no path setup is needed:

   ```python
   import run_stanford_stages
   ```

3. Build a config and run. The public entry point,
   `run_stanford_stages.run_using_json_file(path)`, takes the path to a JSON
   config. Start from the bundled `stanford_stages.xnat.json` (its model paths
   already point at the baked-in `/opt/stanford-stages/ml` assets) and override
   the input and output:

   ```python
   import json, tempfile
   from pathlib import Path

   with open('/opt/stanford-stages/stanford_stages.xnat.json') as fid:
       config = json.load(fid)

   config['edf_filename'] = '/opt/stanford-stages/data/input/CHP040.edf'  # your EDF
   config['output_path'] = str(Path.home() / 'stanford_stages_output')
   Path(config['output_path']).mkdir(parents=True, exist_ok=True)

   config_path = Path(tempfile.gettempdir()) / 'stanford_stages_run.json'
   config_path.write_text(json.dumps(config, indent=2))

   run_stanford_stages.run_using_json_file(str(config_path))
   ```

Results (hypnogram, hypnodensity, encoding, and a hypnodensity plot) are written
directly to `output_path`.

## Pointing at your own recording

- Set `edf_filename` to your EDF. In XNAT, mounted study data appears under your
  workspace - use that path. A sample recording is bundled at
  `/opt/stanford-stages/data/input/CHP040.edf` for a quick end-to-end test.
- **`channel_labels` must match the channel names in your EDF header.** The
  defaults match the bundled sample; other recordings will differ. See
  `documentation/JSON_Configuration.md` for the full set of options (including
  `edf_pathname` to batch a folder of recordings).
- `show.*` options are set to `false` because a spawned container has no display;
  plots are saved to disk via `save.plot: true` and can be shown inline in the
  notebook with `IPython.display.Image`.

## Dependency pins

The Python 3.7 environment is built from `docker/requirements.txt` and
`docker/constraints.txt`, the same pinned, pip-installable stack used by the
root Docker image. The rationale for each pin (Cython, h5py, tensorflow-probability,
and the dropped entries) is documented in
[`README.docker.md`](README.docker.md#dependency-fixes-pip-vs-conda).
